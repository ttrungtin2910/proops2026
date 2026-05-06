#!/usr/bin/env bash

echo "=== Không có pipefail ==="
set -e
cat /file-khong-ton-tai | wc -l
echo "Dòng này có chạy không?"

echo "=== Có pipefail ==="
set -eo pipefail
cat /file-khong-ton-tai | wc -l
echo "Dòng này có chạy không?"

# time timeout 3 ping -c 1 192.0.2.1
# echo "Exit code: $?"