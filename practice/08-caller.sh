#!/usr/bin/env bash
set -euo pipefail

# Bài 3.2 — Caller script: bắt exit code từ 08-exit-codes.sh
# Chạy: bash practice/08-caller.sh

SCRIPT="$(dirname "$0")/08-exit-codes.sh"

run_and_check() {
    local label=$1
    shift
    echo ""
    echo "--- Test: $label ---"
    echo "  Gọi: bash $SCRIPT $*"

    # TODO: gọi $SCRIPT với "$@", lưu exit code vào STATUS
    # Gợi ý: bash "$SCRIPT" "$@" && STATUS=0 || STATUS=$?
    STATUS=0  # xóa dòng này sau khi implement

    # TODO: dùng case để phân biệt exit code
    # case $STATUS in
    #     0) echo "  → Thành công" ;;
    #     1) echo "  → Lỗi runtime (tool thất bại khi chạy)" ;;
    #     2) echo "  → Lỗi misuse (caller gọi sai cách)" ;;
    #     *) echo "  → Exit code không xác định: $STATUS" ;;
    # esac
    echo "  Exit code: $STATUS"
}

run_and_check "Thiếu arg"           # không truyền gì
run_and_check "Env không hợp lệ"  uat
run_and_check "Env hợp lệ nhưng fail" staging
run_and_check "Thành công"         production

echo ""
echo "=== Xong ==="
