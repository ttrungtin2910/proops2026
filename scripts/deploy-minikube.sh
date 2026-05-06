#!/usr/bin/env bash
set -euo pipefail

COMMIT=""

# --- helpers -----------------------------------------------------------------
log()   { echo "[$(date -u +%H:%M:%S)] INFO  $*"; }
err()   { echo "[$(date -u +%H:%M:%S)] ERROR $*" >&2; }
die()   { err "$@"; exit 1; }
usage() {
  cat >&2 <<EOF
Usage: $0 [-n <namespace>] [-d <deployment>]

  -n  K8s namespace     default: default
  -d  Deployment name   default: myapp

Yêu cầu: deployment phải có imagePullPolicy: IfNotPresent (hoặc Never)
         để kubectl dùng image local thay vì kéo từ registry.

Examples:
  $0
  $0 -n dev -d api
EOF
  exit 2
}

# --- pre-flight --------------------------------------------------------------
check_prerequisites() {
  local missing=()
  for cmd in git docker minikube kubectl; do
    command -v "$cmd" >/dev/null || missing+=("$cmd")
  done
  (( ${#missing[@]} == 0 )) || die "Thiếu tool: ${missing[*]}"

  minikube status --format='{{.Host}}' 2>/dev/null | grep -q "Running" \
    || die "Minikube chưa chạy. Khởi động với: minikube start"
}

# --- phase 1: git ------------------------------------------------------------
phase_git() {
  log "Phase 1 — git: fast-forward pull"
  # --ff-only từ chối tạo merge commit nếu local và remote đã diverge.
  # Plain `git pull` sẽ silently merge, khiến COMMIT hash không tương ứng
  # với một tree state sạch và build mất tính reproducible.
  git pull --ff-only \
    || die "git pull --ff-only thất bại — branch đã diverge. Sửa với: git rebase origin/\$(git branch --show-current)"

  COMMIT=$(git rev-parse --short HEAD)
  log "Phase 1 — done. HEAD = $COMMIT"
}

# --- phase 2: build ----------------------------------------------------------
phase_build() {
  local image=$1
  log "Phase 2 — build: $image"
  # Không dùng --platform ở đây: minikube chạy local nên dùng arch của máy host.
  # (Khác EKS — EKS cần ép linux/amd64 vì node là x86_64 dù build trên ARM Mac.)
  docker build -t "$image" . \
    || die "docker build thất bại"
  log "Phase 2 — done. Image built: $image"
}

# --- phase 3: load -----------------------------------------------------------
phase_load() {
  local image=$1
  log "Phase 3 — load: nạp image vào minikube"
  # minikube image load chuyển image từ Docker daemon của host vào container
  # runtime bên trong minikube (containerd/cri-o). Không cần registry.
  # Failure mode cần bắt: image quá lớn + minikube không đủ disk → exit non-zero.
  local load_exit=0
  minikube image load "$image" || load_exit=$?
  (( load_exit == 0 )) \
    || die "minikube image load thất bại (exit $load_exit). Kiểm tra: minikube ssh -- crictl images"
  log "Phase 3 — done. Image loaded vào minikube: $image"
}

# --- phase 4: deploy ---------------------------------------------------------
phase_deploy() {
  local image=$1 deployment=$2 namespace=$3
  log "Phase 4 — deploy: $deployment trong namespace=$namespace"
  kubectl set image "deployment/$deployment" "$deployment=$image" -n "$namespace" \
    || die "kubectl set image thất bại — deployment '$deployment' có tồn tại trong namespace '$namespace' không?"

  kubectl rollout status "deployment/$deployment" -n "$namespace" --timeout=120s \
    || die "Rollout timeout hoặc thất bại. Chẩn đoán: kubectl rollout history deployment/$deployment -n $namespace"
  log "Phase 4 — done. Rollout hoàn tất."
}

# --- main --------------------------------------------------------------------
main() {
  local namespace="default" deployment="myapp"

  while getopts "n:d:h" opt; do
    case $opt in
      n) namespace=$OPTARG   ;;
      d) deployment=$OPTARG  ;;
      *) usage               ;;
    esac
  done

  check_prerequisites

  log "=== deploy-minikube.sh start — deployment=$deployment namespace=$namespace ==="

  phase_git
  local image="myapp:${COMMIT}"

  phase_build "$image"
  phase_load  "$image"
  phase_deploy "$image" "$deployment" "$namespace"

  log "=== deploy-minikube.sh complete — deployed $image ==="
}

main "$@"
