#!/usr/bin/env bash
set -euo pipefail

# Bài 7.3 — SCRIPT_DIR vs CWD: chạy từ 2 thư mục khác nhau và so sánh

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Path comparison ==="
echo "CWD (thay đổi theo nơi gọi):          $(pwd)"
echo "SCRIPT_DIR (luôn trỏ đúng script):    $SCRIPT_DIR"

echo ""
echo "=== Nếu tạo file với relative path ==="
echo "Relative '../output.txt' sẽ tạo tại:  $(pwd)/../output.txt"
echo "Absolute sẽ tạo tại:                  $SCRIPT_DIR/../output.txt"

echo ""
echo "=== Tạo file thật để kiểm chứng ==="
touch "$(pwd)/../relative-test.txt"
touch "$SCRIPT_DIR/../absolute-test.txt"
echo "relative-test.txt tạo tại: $(realpath "$(pwd)/../relative-test.txt")"
echo "absolute-test.txt tạo tại: $(realpath "$SCRIPT_DIR/../absolute-test.txt")"

echo ""
echo "--- Thử chạy lại từ thư mục khác ---"
echo "cd /tmp && bash $SCRIPT_DIR/13-scriptdir.sh"
echo "Quan sát: CWD thay đổi, SCRIPT_DIR vẫn giữ nguyên."

# Dọn dẹp
rm -f "$(pwd)/../relative-test.txt" "$SCRIPT_DIR/../absolute-test.txt"
