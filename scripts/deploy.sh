#!/usr/bin/env bash
set -euo pipefail

COMMIT=""
INSTANCE_ID=""   # EC2 instance ID cho preflight check (-i flag)
HOST=""          # Host của health endpoint cho preflight check (-H flag)
DRY_RUN=0        # 1 nếu --dry-run được truyền vào

# --- helpers -----------------------------------------------------------------
_ts()   { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Structured phase logging — mỗi phase emit START → OK hoặc FAIL.
# Format cố định để CI log viewer có thể grep: `\[git\] FAIL` tìm đúng phase.
start() { echo "[$(_ts)] [$1] START $2"; }
ok()    { echo "[$(_ts)] [$1] OK $2"; }
fail()  { echo "[$(_ts)] [$1] FAIL $2" >&2; exit 1; }

# Non-phase messages (setup, idempotency, state) dùng tag [deploy].
log()   { echo "[$(_ts)] [deploy] INFO $*"; }
die()   { echo "[$(_ts)] [deploy] FAIL $*" >&2; exit 1; }

# run(): wrapper cho lệnh có side-effect.
# Dry-run → in lệnh ra stdout thay vì thực thi. Trả về 0 nên các check
# exit code sau đó (push_exit, v.v.) vẫn hoạt động đúng trong dry-run.
# Lệnh read-only (git rev-parse, aws describe-*, curl, cat) KHÔNG qua run()
# vì output của chúng cần thiết cho logic phía sau.
run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[$(_ts)] [deploy] DRY-RUN: $*"
  else
    "$@"
  fi
}

usage() {
  cat >&2 <<EOF
Usage: $0 -r <registry> [--dry-run] [-i <instance-id>] [-H <host>] [-n <namespace>] [-d <deployment>]

  -r          Registry prefix    e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com
  --dry-run   In lệnh sẽ chạy, không thực thi — dùng để review trước khi deploy thật
  -i          EC2 Instance ID    e.g. i-0abc1234def56789
  -H          Health check host  e.g. api.myapp.com
  -n          K8s namespace      default: default
  -d          Deployment name    default: myapp

Examples:
  $0 -r 123456789.dkr.ecr.us-east-1.amazonaws.com --dry-run
  $0 -r 123456789.dkr.ecr.us-east-1.amazonaws.com -i i-0abc1234 -H api.myapp.com
  $0 -r ghcr.io/myorg -n production -d api
EOF
  exit 2
}

# --- check_prerequisites -----------------------------------------------------
check_prerequisites() {
  local missing=()
  for cmd in git docker kubectl aws; do
    command -v "$cmd" >/dev/null || missing+=("$cmd")
  done
  (( ${#missing[@]} == 0 )) || die "Thiếu tool: ${missing[*]}"

  local ctx
  ctx=$(kubectl config current-context 2>/dev/null) \
    || die "kubectl không có context nào. Chạy: aws eks update-kubeconfig --name <cluster>"
  log "kubectl context: $ctx"
}

# --- preflight ---------------------------------------------------------------
preflight() {
  local instance_id=$1 host=$2

  if [[ -n "$instance_id" ]]; then
    start preflight "EC2 state $instance_id"
    # Read-only: không qua run() — cần output để so sánh state.
    local state
    state=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text) \
      || fail preflight "aws describe-instances failed — check AWS credentials"
    [[ "$state" == "running" ]] \
      || fail preflight "instance $instance_id is '$state' — wait with: aws ec2 wait instance-running --instance-ids $instance_id"
    ok preflight "EC2 $instance_id is running"
  fi

  if [[ -n "$host" ]]; then
    start preflight "health http://$host/health"
    # Read-only: không qua run() — cần HTTP status code để quyết định có deploy không.
    # `|| echo "000"`: nếu curl fail hoàn toàn (timeout, DNS lỗi), vẫn nhận string
    # để so sánh thay vì set -e crash script.
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://$host/health" \
      || echo "000")
    [[ "$status" == "200" ]] \
      || fail preflight "health returned $status — service unhealthy before deploy. Check: curl -v http://$host/health"
    ok preflight "$host returned $status"
  fi
}

# --- phase 1: git ------------------------------------------------------------
phase_git() {
  start git "pulling latest"
  # Mutating: thay đổi local state → qua run().
  # --ff-only từ chối tạo merge commit nếu local và remote đã diverge.
  run git pull --ff-only \
    || fail git "fast-forward not possible — branch diverged. Fix: git rebase origin/\$(git branch --show-current)"
  # Read-only: đọc HEAD sau pull → không qua run(), output cần cho image tag.
  COMMIT=$(git rev-parse --short HEAD)
  ok git "at $COMMIT"
}

# --- phase 2: build ----------------------------------------------------------
phase_build() {
  local image=$1
  start build "$image"
  # Mutating: tạo image mới → qua run().
  # --platform=linux/amd64: ép arch target là x86_64 để image chạy được trên
  # EKS node (Linux x86_64), kể cả khi build trên ARM Mac (M1/M2).
  run docker build --platform=linux/amd64 -t "$image" . \
    || fail build "docker build exited $?"
  ok build "$image"
}

# --- phase 3: push -----------------------------------------------------------
phase_push() {
  local image=$1
  start push "$image"
  # Mutating: push lên registry → qua run().
  # Bắt exit code tường minh: token ECR hết hạn → exit 1, không có output stdout.
  # Trong dry-run, run() trả về 0 → push_exit = 0 → script tiếp tục đúng.
  local push_exit=0
  run docker push "$image" || push_exit=$?
  (( push_exit == 0 )) \
    || fail push "docker push exited $push_exit — refresh ECR token: aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <registry>"
  ok push "$image"
}

# --- phase 4: deploy ---------------------------------------------------------
phase_deploy() {
  local image=$1 deployment=$2 namespace=$3
  start deploy "$deployment → $image"
  # Cả hai kubectl lệnh đều mutating → qua run().
  run kubectl set image "deployment/$deployment" "$deployment=$image" -n "$namespace" \
    || fail deploy "kubectl set image failed — does '$deployment' exist in namespace '$namespace'?"
  # rollout status block cho đến khi pod mới pass readiness check hoặc hết timeout.
  run kubectl rollout status "deployment/$deployment" -n "$namespace" --timeout=120s \
    || fail deploy "rollout timed out — diagnose: kubectl rollout history deployment/$deployment -n $namespace"
  ok deploy "rollout complete ($deployment in $namespace)"
}

# --- main --------------------------------------------------------------------
main() {
  local registry="" namespace="default" deployment="myapp"

  # Pre-process --dry-run trước getopts vì getopts không support long options.
  # Rebuild $@ mà không có --dry-run để getopts xử lý các short flags bình thường.
  local filtered=()
  for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=1 || filtered+=("$arg")
  done
  if (( ${#filtered[@]} > 0 )); then
    set -- "${filtered[@]}"
  else
    set --
  fi

  while getopts "r:i:H:n:d:h" opt; do
    case $opt in
      r) registry=$OPTARG     ;;
      i) INSTANCE_ID=$OPTARG  ;;
      H) HOST=$OPTARG         ;;
      n) namespace=$OPTARG    ;;
      d) deployment=$OPTARG   ;;
      *) usage                ;;
    esac
  done

  [[ -n "$registry" ]] || usage

  [[ $DRY_RUN -eq 1 ]] && log "DRY-RUN mode — lệnh mutating sẽ được in, không thực thi"

  check_prerequisites
  preflight "$INSTANCE_ID" "$HOST"

  log "starting — registry=$registry deployment=$deployment namespace=$namespace"

  phase_git
  local image="${registry}/myapp:${COMMIT}"

  # --- idempotency check -----------------------------------------------------
  # Read-only: đọc state file → không qua run().
  local last
  last=$(cat .last-deploy 2>/dev/null || echo "")
  if [[ "$COMMIT" == "$last" ]]; then
    log "SKIP no changes since last deploy ($COMMIT)"
    exit 0
  fi
  log "new commit detected: ${last:-<none>} → $COMMIT"
  # ---------------------------------------------------------------------------

  phase_build  "$image"
  phase_push   "$image"
  phase_deploy "$image" "$deployment" "$namespace"

  # Ghi state SAU KHI deploy thành công.
  # Mutating: ghi file → kiểm tra DRY_RUN trực tiếp (không dùng run() vì
  # redirect > không thể truyền qua $@ của một hàm).
  if [[ $DRY_RUN -eq 1 ]]; then
    log "DRY-RUN: echo $COMMIT > .last-deploy"
  else
    echo "$COMMIT" > .last-deploy
    log "state saved → .last-deploy ($COMMIT)"
  fi

  log "DONE deployed $image"
}

main "$@"
