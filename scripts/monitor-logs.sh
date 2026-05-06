#!/usr/bin/env bash
# Cron entry ví dụ:
#   PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin
#   */5 * * * * /path/to/monitor-logs.sh -f /var/log/app.log >> /var/log/monitor-logs.log 2>&1
set -euo pipefail

# Fix PATH cho cron — cron chỉ có /usr/bin:/bin, thiếu tail/grep của homebrew trên Mac.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

# Config — có thể override qua flag hoặc env var
DEDUP_FILE="${DEDUP_FILE:-/tmp/monitor-dedup}"
ALERT_LOG="${ALERT_LOG:-/tmp/alerts.log}"
DEDUP_TTL=3600   # giây — entry cũ hơn thế này có thể alert lại

# --- helpers -----------------------------------------------------------------
_ts()   { date -u +%Y-%m-%dT%H:%M:%SZ; }
log()   { echo "[$(_ts)] [monitor] INFO $*"; }
die()   { echo "[$(_ts)] [monitor] FAIL $*" >&2; exit 1; }
usage() {
  cat >&2 <<EOF
Usage: $0 [-f <logfile>] [-d <dedup-file>] [-a <alert-log>] [-t <ttl-seconds>]

  -f  Log file cần theo dõi   default: /var/log/app.log
  -d  File lưu dedup hashes   default: /tmp/monitor-dedup
  -a  File ghi alert output   default: /tmp/alerts.log
  -t  Dedup TTL (giây)        default: 3600

Examples:
  $0
  $0 -f /var/log/nginx/error.log -t 1800
EOF
  exit 2
}

# --- dedup pruning -----------------------------------------------------------
prune_dedup() {
  [[ -f "$DEDUP_FILE" ]] || return 0
  local cutoff
  cutoff=$(( $(date +%s) - DEDUP_TTL ))
  # awk giữ lại chỉ những entry có timestamp > cutoff.
  # Ghi vào .tmp rồi mv để tránh truncate file đang đọc.
  awk -v cutoff="$cutoff" '$2 > cutoff' "$DEDUP_FILE" > "$DEDUP_FILE.tmp" \
    && mv "$DEDUP_FILE.tmp" "$DEDUP_FILE"
  log "dedup pruned — cutoff=${cutoff}s, file=$DEDUP_FILE"
}

# --- alert -------------------------------------------------------------------
send_alert() {
  local line=$1
  # Hôm nay: ghi ra file. Production: curl đến webhook.
  echo "[$(_ts)] ALERT $line" >> "$ALERT_LOG"
  log "alert → $ALERT_LOG"

  # Production pattern (bỏ comment khi có webhook):
  # curl -s -X POST "$SLACK_WEBHOOK_URL" \
  #   -H 'Content-type: application/json' \
  #   --data "{\"text\":\"[ALERT] $(date -u): $line\"}" \
  #   || log "webhook delivery failed (non-fatal)"
}

# --- monitor loop ------------------------------------------------------------
monitor() {
  local logfile=$1
  log "monitoring $logfile (dedup=$DEDUP_FILE, ttl=${DEDUP_TTL}s, alerts=$ALERT_LOG)"

  # Prune entries cũ ngay khi start — entry > TTL có thể alert lại.
  # Không prune trong loop để tránh race condition khi ghi .tmp.
  prune_dedup

  # tail -F (hoa): theo dõi theo tên file, không theo inode.
  #   → tự reconnect sau khi file bị rotate (logrotate, Docker log rotation).
  #   tail -f (thường): follow inode → mất track sau khi rotate, alert tắt im lặng.
  #
  # grep --line-buffered: flush mỗi dòng ngay lập tức thay vì buffer block 4KB.
  #   → không có --line-buffered, alert bị giữ trong buffer và đến theo batch,
  #   không phải real-time.
  tail -F "$logfile" \
    | grep --line-buffered -E '\[ERROR\]|\bERROR\b' \
    | while read -r line; do

        # 12 ký tự đầu của sha256 — đủ để dedup log message, collision rate ~1/10^14.
        local key
        key=$(echo "$line" | sha256sum | cut -c1-12)

        # `if grep -q` an toàn với set -e: lệnh trong điều kiện if không trigger exit.
        # grep trả về exit 1 (no match) → vào nhánh else, không crash script.
        if grep -q "^$key " "$DEDUP_FILE" 2>/dev/null; then
          log "dedup hit — suppressed: $key"
          continue   # đã alert rồi, bỏ qua
        fi

        # Ghi hash + unix timestamp SAU KHI quyết định alert, TRƯỚC KHI gửi.
        # Nếu send_alert fail, entry vẫn được ghi → không alert lại lần sau.
        echo "$key $(date +%s)" >> "$DEDUP_FILE"
        send_alert "$line"
      done
}

# --- main --------------------------------------------------------------------
main() {
  local logfile="/var/log/app.log"

  while getopts "f:d:a:t:h" opt; do
    case $opt in
      f) logfile=$OPTARG    ;;
      d) DEDUP_FILE=$OPTARG ;;
      a) ALERT_LOG=$OPTARG  ;;
      t) DEDUP_TTL=$OPTARG  ;;
      *) usage              ;;
    esac
  done

  [[ -f "$logfile" ]] || die "log file không tồn tại: $logfile"
  [[ "$DEDUP_TTL" =~ ^[0-9]+$ ]] || die "TTL phải là số nguyên dương: $DEDUP_TTL"

  monitor "$logfile"
}

main "$@"
