#!/usr/bin/env bash
set -euo pipefail

# Bài 6.3 — Script cấu trúc chuẩn: kiểm tra HTTP của một domain
# Thứ tự BẮT BUỘC: constants → helpers → domain functions → main → main "$@"

# ── 1. CONSTANTS ─────────────────────────────────────────────
# TODO: khai báo ít nhất 2 readonly constants
# readonly TIMEOUT=...
# readonly ...


# ── 2. HELPERS ───────────────────────────────────────────────
# TODO: viết 4 helper functions: log(), err(), die(), usage()
# log()   { ... }
# err()   { ... }
# die()   { ... }
# usage() { ... exit 2; }


# ── 3. PREFLIGHT ─────────────────────────────────────────────
# TODO: viết check_prerequisites() kiểm tra curl tồn tại
# check_prerequisites() {
#     ...
# }


# ── 4. DOMAIN FUNCTIONS ──────────────────────────────────────
# TODO: viết check_domain() nhận 1 arg là domain
# - dùng curl -sS --max-time "$TIMEOUT" để gọi https://<domain>
# - dùng if output=$(...); then để bắt kết quả
# - log thành công, err thất bại, return 1 nếu fail
# check_domain() {
#     local domain=$1
#     ...
# }


# ── 5. MAIN ──────────────────────────────────────────────────
# TODO: viết main() với đúng thứ tự:
#   1. parse flag -h/--help → gọi usage
#   2. kiểm tra $# -lt 1 → gọi usage
#   3. gán DOMAIN=$1
#   4. gọi check_prerequisites
#   5. gọi check_domain "$DOMAIN"
# main() {
#     ...
# }


# ── 6. ENTRY POINT ───────────────────────────────────────────
# TODO: uncomment dòng dưới sau khi viết xong main()
# main "$@"
