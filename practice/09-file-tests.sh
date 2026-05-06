#!/usr/bin/env bash
set -euo pipefail

# Bài 5.1 — Quan sát kết quả file tests trên các loại path khác nhau

check_file() {
    local path=$1
    echo ""
    echo "=== $path ==="
    [[ -e "$path" ]] && echo "  -e: tồn tại"            || echo "  -e: không tồn tại"
    [[ -f "$path" ]] && echo "  -f: là regular file"    || echo "  -f: không phải regular file"
    [[ -d "$path" ]] && echo "  -d: là directory"       || echo "  -d: không phải directory"
    [[ -r "$path" ]] && echo "  -r: readable"           || echo "  -r: không readable"
    [[ -w "$path" ]] && echo "  -w: writable"           || echo "  -w: không writable"
    [[ -x "$path" ]] && echo "  -x: executable"         || echo "  -x: không executable"
    [[ -s "$path" ]] && echo "  -s: không rỗng (size>0)" || echo "  -s: rỗng hoặc không tồn tại"
}

check_file "/etc/passwd"       # regular file, readable
check_file "/tmp"              # directory — tại sao -f false?
check_file "/usr/bin/curl"     # executable binary
check_file "/etc/shadow"       # có thể không readable (permission)
check_file "/nonexistent"      # không tồn tại — mọi test đều false

# Câu hỏi tự trả lời sau khi chạy:
echo ""
echo "--- Câu hỏi ---"
echo "1. /tmp trả về -f false nhưng -e true. Tại sao nên dùng -f thay -e khi đọc log file?"
echo "2. Nếu ai đó tạo thư mục tên /var/log/app.log, -e vẫn true."
echo "   Script của bạn sẽ làm gì tiếp theo nếu chỉ check -e?"
