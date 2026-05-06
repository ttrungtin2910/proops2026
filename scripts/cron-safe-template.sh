#!/usr/bin/env bash
# =============================================================================
# Cron-safe script template
# Copy file này, đổi SCRIPT_NAME và viết logic vào main().
#
# Test trước khi schedule:
#   env -i PATH=/usr/bin:/bin HOME=$HOME /path/to/this-script.sh
# Nếu chạy được trong môi trường stripped đó thì cron cũng chạy được.
# =============================================================================
set -euo pipefail

# Fix #1 — PATH tường minh.
# Cron chạy với PATH=/usr/bin:/bin — không có /usr/local/bin, không có brew.
# Kết quả: "jq: command not found", "aws: command not found" dù script chạy
# tốt trong terminal của bạn. Khai báo ở đây thay vì dựa vào môi trường shell.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

# Fix #2 — Env vars tường minh.
# Cron không load ~/.bashrc hay ~/.profile nên không có biến môi trường nào
# bạn đã set ở đó. Khai báo rõ ràng ở đây hoặc trong crontab entry.
# export AWS_PROFILE="prod"
# export AWS_DEFAULT_REGION="us-east-1"
# export KUBECONFIG="/home/deploy/.kube/config"

# Fix #5 — Output redirect.
# Mặc định cron cố gửi output qua mail — thường bị drop hoặc tắt.
# Redirect ngay trong crontab entry:
#   */5 * * * * /path/to/this-script.sh >> /var/log/this-script.log 2>&1

SCRIPT_NAME="$(basename "$0" .sh)"
LOCK_FILE="/tmp/${SCRIPT_NAME}.lock"
DRY_RUN=0

# --- helpers -----------------------------------------------------------------
_ts()  { date -u +%Y-%m-%dT%H:%M:%SZ; }
log()  { echo "[$(_ts)] [$SCRIPT_NAME] INFO $*"; }
die()  { echo "[$(_ts)] [$SCRIPT_NAME] FAIL $*" >&2; exit 1; }

# run(): bao bọc lệnh có side-effect.
# --dry-run → in lệnh thay vì thực thi; read-only commands không cần qua run().
run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[$(_ts)] [$SCRIPT_NAME] DRY-RUN: $*"
  else
    "$@"
  fi
}

usage() {
  cat >&2 <<EOF
Usage: $0 [--dry-run] [--help]

  --dry-run   In lệnh sẽ chạy mà không thực thi
  --help      Hiển thị help này
EOF
  exit 2
}

# --- lock: ngăn overlapping runs ---------------------------------------------
# Nếu script chạy lâu hơn interval cron (e.g. cron mỗi 5 phút nhưng script
# chạy 7 phút), lần chạy thứ hai sẽ exit 0 thay vì chạy song song và gây conflict.
acquire_lock() {
  exec 9>"$LOCK_FILE"
  flock -n 9 || { log "SKIP another instance is running (lock: $LOCK_FILE)"; exit 0; }
}

# --- main --------------------------------------------------------------------
main() {
  # Parse --dry-run trước (getopts không support long options).
  local filtered=()
  for arg in "$@"; do
    case "$arg" in
      --dry-run) DRY_RUN=1 ;;
      --help)    usage ;;
      *)         filtered+=("$arg") ;;
    esac
  done
  if (( ${#filtered[@]} > 0 )); then
    set -- "${filtered[@]}"
  else
    set --
  fi

  [[ $DRY_RUN -eq 1 ]] && log "DRY-RUN mode — lệnh mutating sẽ được in, không thực thi"

  log "starting"

  # === viết logic của bạn ở đây ===
  # Lệnh có side-effect → dùng run():
  #   run docker build -t myapp:latest .
  #   run kubectl apply -f deployment.yaml
  #
  # Lệnh read-only → gọi trực tiếp (output cần cho logic):
  #   COMMIT=$(git rev-parse --short HEAD)
  #   STATE=$(aws ec2 describe-instances ...)

  log "done"
}

acquire_lock
main "$@"
