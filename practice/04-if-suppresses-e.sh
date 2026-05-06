#!/usr/bin/env bash
set -euo pipefail



echo "Trước if"
if ping -c 1 -W 1 192.0.2.1 &>/dev/null; then
    echo "Host online"
else
    echo "Host offline — nhưng script tiếp tục"
fi
echo "Sau if — script vẫn chạy"