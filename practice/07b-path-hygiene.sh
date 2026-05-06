#!/usr/bin/env bash
set -euo pipefail

# Bài 7.1 + 7.2 — PATH hygiene: simulate cron environment

echo "=============================="
echo " Bài 7.1 — Interactive vs Cron PATH"
echo "=============================="
echo ""

echo "PATH hiện tại (interactive shell):"
echo "$PATH" | tr ':' '\n' | sed 's/^/  /'

echo ""
echo "PATH trong môi trường cron (simulate với env -i):"
env -i PATH=/usr/bin:/bin HOME="$HOME" bash -c 'echo $PATH' | tr ':' '\n' | sed 's/^/  /'

echo ""
echo "=============================="
echo " Kiểm tra từng tool trong PATH cron"
echo "=============================="
echo ""

TOOLS=(jq aws kubectl curl docker python3 terraform)

for tool in "${TOOLS[@]}"; do
    # Tìm trong PATH đầy đủ
    full_path=$(command -v "$tool" 2>/dev/null || echo "NOT FOUND")

    # Tìm trong PATH cron
    cron_path=$(env -i PATH=/usr/bin:/bin HOME="$HOME" bash -c \
        "command -v $tool 2>/dev/null || echo 'NOT FOUND'")

    if [[ "$cron_path" == "NOT FOUND" ]]; then
        echo "  ✗ $tool"
        echo "    Full PATH: $full_path"
        echo "    Cron PATH: NOT FOUND  ← sẽ fail trong cron!"
    else
        echo "  ✓ $tool → $cron_path"
    fi
done

echo ""
echo "=============================="
echo " Bài 7.2 — Preflight check pattern"
echo "=============================="
echo ""

check_prerequisites() {
    local missing=()
    # Thêm tool thật bạn cần vào đây
    for cmd in curl bash notexist-tool-abc; do
        command -v "$cmd" >/dev/null || missing+=("$cmd")
    done

    if (( ${#missing[@]} > 0 )); then
        echo "ERROR: Thiếu tool bắt buộc: ${missing[*]}" >&2
        echo "       Script dừng sớm với thông báo rõ ràng."
        echo "       (thay vì crash ở giữa chừng với 'command not found')"
        return 1
    fi

    echo "Tất cả tool OK"
}

check_prerequisites || true

echo ""
echo "--- So sánh command -v vs which ---"
echo "which curl:      $(which curl 2>/dev/null || echo 'không đáng tin')"
echo "command -v curl: $(command -v curl 2>/dev/null || echo 'NOT FOUND')"
echo ""
echo "which nonexist:      $(which nonexist 2>/dev/null || echo 'exit non-zero')"
echo "command -v nonexist: $(command -v nonexist 2>/dev/null || echo 'exit non-zero (luôn đúng)')"
