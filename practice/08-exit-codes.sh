#!/usr/bin/env bash
set -euo pipefail

# Bài 3.2 — Phân biệt exit 1 và exit 2
# Script nhận <env> và trả về exit code có ý nghĩa khác nhau

die()   { echo "ERROR: $*" >&2; exit 1; }
usage() { echo "Usage: $0 <env>   (env: dev | staging | production)" >&2; exit 2; }

# TODO 1: Thiếu argument → exit 2
# Gợi ý: [[ $# -lt 1 ]] && usage


# TODO 2: Env không hợp lệ → exit 2 (caller gọi sai, không phải lỗi runtime)
# Gợi ý: [[ $ENV =~ ^(dev|staging|production)$ ]] || ...
ENV=${1:-}


# TODO 3: Giả lập không kết nối được → exit 1 (lỗi runtime)
# Gợi ý: dùng biến SIMULATE_FAILURE=true để test
# if [[ "$ENV" == "staging" ]]; then
#     die "Không kết nối được tới $ENV cluster"
# fi


# TODO 4: Thành công → in thông báo và exit 0
echo "Kết nối tới $ENV thành công"
