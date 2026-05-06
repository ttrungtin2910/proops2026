#!/usr/bin/env bash
# Bài 4.1 + 4.2 — Quan sát stream redirection
# Chạy từng block, đọc output và giải thích

echo "=============================="
echo " Bài 4.1 — stdout vs stderr"
echo "=============================="
echo ""

echo "--- Case 1: stdout vào file, stderr ra terminal ---"
ls /tmp /nonexistent > /tmp/out.txt 2>/dev/null || true
echo "Nội dung out.txt:"
cat /tmp/out.txt
echo "(stderr đã bị redirect 2>/dev/null để không làm nhiễu bài này)"

echo ""
echo "--- Case 2: stderr vào file, stdout ra terminal ---"
ls /tmp /nonexistent 2> /tmp/err.txt || true
echo "Nội dung err.txt:"
cat /tmp/err.txt

echo ""
echo "--- Case 3: cả hai vào cùng file (thứ tự ĐÚNG) ---"
ls /tmp /nonexistent > /tmp/both.txt 2>&1 || true
echo "Nội dung both.txt (có cả stdout và stderr):"
cat /tmp/both.txt

echo ""
echo "--- Case 4: thứ tự NGƯỢC — 2>&1 trước > file ---"
ls /tmp /nonexistent 2>&1 > /tmp/wrong.txt || true
echo "Nội dung wrong.txt (chỉ có stdout — stderr ra terminal):"
cat /tmp/wrong.txt
echo "(stderr đã hiện trên terminal ở trên, KHÔNG vào file)"

echo ""
echo "=============================="
echo " Bài 4.2 — curl và stderr"
echo "=============================="
echo ""

echo "--- curl không có flag: progress bar đi vào stderr ---"
echo "(Chạy lệnh dưới thủ công để thấy progress bar trên terminal)"
echo "  curl https://httpbin.org/get > /tmp/curl-out.txt"
echo ""

echo "--- curl -s: tắt cả progress và error ---"
curl -s https://httpbin.org/get > /tmp/curl-s.txt 2>/dev/null || true
echo "curl -s output (chỉ JSON, không progress):"
head -3 /tmp/curl-s.txt

echo ""
echo "--- curl -sS: tắt progress, GIỮ error messages ---"
echo "Thử với URL lỗi:"
curl -sS "http://localhost:19999/nonexistent" > /tmp/curl-ss.txt 2>/tmp/curl-ss-err.txt || true
echo "stdout (vào file):"; cat /tmp/curl-ss.txt
echo "stderr (giữ lại):";  cat /tmp/curl-ss-err.txt

echo ""
echo "--- Vẽ sơ đồ fd cho Case 3 và Case 4 ---"
echo "Case 3: cmd > file 2>&1"
echo "  Bước 1: > file   → fd1 trỏ tới FILE"
echo "  Bước 2: 2>&1     → fd2 trỏ tới 'chỗ fd1 đang trỏ' = FILE"
echo "  Kết quả: fd1→FILE, fd2→FILE"
echo ""
echo "Case 4: cmd 2>&1 > file"
echo "  Bước 1: 2>&1     → fd2 trỏ tới 'chỗ fd1 đang trỏ' = TERMINAL"
echo "  Bước 2: > file   → fd1 trỏ tới FILE"
echo "  Kết quả: fd1→FILE, fd2→TERMINAL"

# Dọn dẹp
rm -f /tmp/out.txt /tmp/err.txt /tmp/both.txt /tmp/wrong.txt /tmp/curl-s.txt /tmp/curl-ss.txt /tmp/curl-ss-err.txt
