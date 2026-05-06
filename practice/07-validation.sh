#!/usr/bin/env bash
set -euo pipefail

# Bài 3.1 — Ba pattern validation + kiểm tra giá trị
# Nhận 2 argument: <host> <port>

# ── Helper ───────────────────────────────────────────────────
log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] INFO  $*"; }
err()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR $*" >&2; }
die()   { err "$@"; exit 1; }

# ── Pattern 3: usage() function ──────────────────────────────
# Gọi khi --help hoặc args sai — luôn exit 2 (misuse)
usage() {
    echo "Usage: $0 <host> <port>" >&2
    echo "  host  hostname hoặc IP cần kết nối" >&2
    echo "  port  số nguyên trong khoảng 1–65535" >&2
    exit 2
}

# ── Pattern 1: kiểm tra $# thủ công ─────────────────────────
# $# = số lượng positional arguments (không tính $0)
[[ ${1:-} == "-h" || ${1:-} == "--help" ]] && usage
if [[ $# -lt 2 ]]; then
    err "Thiếu argument: cần 2, nhận được $#"
    usage
fi

# ── Pattern 2: ${var:?msg} ───────────────────────────────────
# Nếu $1 hoặc $2 unset/rỗng → in msg ra stderr và exit non-zero
HOST="${1:?Usage: $0 <host> <port>}"
PORT="${2:?Usage: $0 <host> <port>}"

# ── Validate giá trị (không chỉ sự tồn tại) ─────────────────
# port phải là số nguyên dương
[[ $PORT =~ ^[0-9]+$ ]]              || die "port phải là số nguyên: '$PORT'"
# port phải trong khoảng hợp lệ
[[ $PORT -ge 1 && $PORT -le 65535 ]] || die "port ngoài khoảng 1–65535: $PORT"

# ── Output ───────────────────────────────────────────────────
log "OK: $HOST:$PORT"