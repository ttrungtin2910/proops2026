#!/usr/bin/env bash
set -euo pipefail

URL="https://api.example.com/health"

# Gán output vào biến TRONG vị trí điều kiện của if
# → -e bị tắt cho lệnh này, exit code đi vào if/else
if output=$(curl -s --max-time 5 "$URL"); then
    echo "Phản hồi nhận được: $output"
    # Kiểm tra nội dung phản hồi
    if echo "$output" | grep -q '"status":"ok"'; then
        echo "API khỏe mạnh"
    else
        echo "API phản hồi nhưng status không ok: $output" >&2
        exit 1
    fi
else
    echo "Fetch thất bại (timeout hoặc lỗi mạng)" >&2
    exit 1
fi
