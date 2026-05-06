#!/usr/bin/env bash
set -euo pipefail

# Bài Tổng Hợp — deploy-check.sh
# Viết từ đầu, không copy healthcheck.sh
#
# Chức năng:
#   - Nhận <cluster> <namespace>, flag -d cho dry-run
#   - Kiểm tra kubectl và aws có trong PATH
#   - Kiểm tra cluster có kết nối không (kubectl cluster-info)
#   - Kiểm tra namespace tồn tại, nếu không thì tạo
#   - Log mỗi bước với timestamp
#   - Dry-run: in lệnh nhưng không thực thi

# ── CONSTANTS ────────────────────────────────────────────────
# TODO: khai báo readonly constants cần thiết


# ── HELPERS ──────────────────────────────────────────────────
# TODO: log() err() die() usage()
# usage phải in: "Usage: $0 [-d] <cluster> <namespace>"
# usage phải exit 2


# ── PREFLIGHT ────────────────────────────────────────────────
# TODO: check_prerequisites() — kiểm tra kubectl và aws


# ── DOMAIN FUNCTIONS ─────────────────────────────────────────
# TODO: check_cluster() — chạy kubectl cluster-info
#   dùng if cmd; then (expected failure khi cluster offline)
#   log OK hoặc die nếu thất bại

# TODO: ensure_namespace() — kiểm tra namespace, tạo nếu chưa có
#   kubectl get namespace "$ns" &>/dev/null || kubectl create namespace "$ns"
#   nếu dry_run=true: chỉ echo lệnh, không chạy thật


# ── MAIN ─────────────────────────────────────────────────────
# TODO: main() với thứ tự:
#   1. parse -d flag (dry_run=true) và -h (usage)
#   2. shift $((OPTIND - 1))
#   3. [[ $# -lt 2 ]] && usage
#   4. gán CLUSTER=$1 NAMESPACE=$2
#   5. validate (không rỗng, regex hợp lệ nếu muốn)
#   6. check_prerequisites
#   7. check_cluster "$CLUSTER"
#   8. ensure_namespace "$NAMESPACE" "$dry_run"
#   9. log "Tất cả kiểm tra passed"


# ── ENTRY POINT ──────────────────────────────────────────────
# TODO: uncomment sau khi viết xong
# main "$@"


# ── CHECKLIST (tự đánh dấu trước khi xem đáp án) ─────────────
# [ ] set -euo pipefail ở dòng 2
# [ ] readonly constants
# [ ] log() err() die() usage()
# [ ] check_prerequisites() với command -v loop
# [ ] usage() exit 2, die() exit 1
# [ ] local vars trong mỗi function, tách local và gán 2 dòng
# [ ] if cmd; then cho expected failures
# [ ] || true chỉ ở chỗ hợp lý
# [ ] 2>/dev/null hoặc &>/dev/null đúng chỗ
# [ ] main() chỉ orchestrate
# [ ] main "$@" ở dòng cuối
# [ ] shellcheck không warning
