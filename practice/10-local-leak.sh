#!/usr/bin/env bash
set -euo pipefail

# Bài 6.1 — Quan sát local variable leak

# Hàm KHÔNG dùng local — biến result bị ghi vào global scope
process_without_local() {
    result="processed: $1"
}

# Hàm DÙNG local — biến result chỉ sống trong function
process_with_local() {
    local result
    result="processed: $1"
}

echo "=== without_local ==="
result="giá trị quan trọng"
echo "Trước khi gọi: result = '$result'"
process_without_local "input"
echo "Sau khi gọi:   result = '$result'"
echo "→ Biến bị ghi đè!"

echo ""
echo "=== with_local ==="
result="giá trị quan trọng"
echo "Trước khi gọi: result = '$result'"
process_with_local "input"
echo "Sau khi gọi:   result = '$result'"
echo "→ Biến được bảo vệ."

# Thêm: leak trong vòng lặp
echo ""
echo "=== Leak trong vòng lặp ==="
i=100
for i in 1 2 3; do
    :  # không làm gì
done
echo "Sau vòng lặp: i = $i  (bị ghi đè bởi loop variable!)"
# Fix: dùng local i trong function nếu loop nằm trong function
