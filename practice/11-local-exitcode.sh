#!/usr/bin/env bash
set -euo pipefail

# Bài 6.2 — local var=$(cmd) che exit code: so sánh bad vs good

bad_function() {
    # MỘT dòng: exit code của 'local' luôn là 0 — che đi lỗi của cmd bên phải
    local result=$(cat /file-khong-ton-tai 2>/dev/null)
    echo "bad_function chạy tiếp được: result='$result'"
}

good_function() {
    # HAI dòng: exit code của cmd bên phải được -e bắt bình thường
    local result
    result=$(cat /file-khong-ton-tai 2>/dev/null)
    echo "good_function chạy tiếp được: result='$result'"
}

echo "=== bad_function ==="
bad_function \
    && echo "→ Kết thúc bình thường (lỗi bị che!)" \
    || echo "→ Thất bại với exit: $?"

echo ""
echo "=== good_function ==="
good_function \
    && echo "→ Kết thúc bình thường" \
    || echo "→ Thất bại với exit: $?"

echo ""
echo "--- Giải thích ---"
echo "bad_function:  'local result=\$(cmd)' → exit code của dòng = exit code của 'local' = 0"
echo "good_function: 'result=\$(cmd)'       → exit code của dòng = exit code của 'cmd'"
echo "Với set -e: bad không dừng, good dừng đúng chỗ."
