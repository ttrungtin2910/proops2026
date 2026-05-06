#!/usr/bin/env bash
# Bài 5.2 + 5.3 — Bẫy so sánh số/string và word splitting

echo "=============================="
echo " Bài 5.2 — String vs Number compare"
echo "=============================="
echo ""

echo "--- So sánh string (>) dùng thứ tự ASCII ---"
[[ "9" > "10" ]]  && echo '  [[ "9" > "10" ]]  → TRUE  (sai logic! "9" > "1" theo ASCII)' \
                  || echo '  [[ "9" > "10" ]]  → false'
[[ "20" > "9" ]]  && echo '  [[ "20" > "9" ]]  → TRUE' \
                  || echo '  [[ "20" > "9" ]]  → FALSE (sai! "2" < "9" theo ASCII)'

echo ""
echo "--- So sánh số (-gt) dùng giá trị số thật ---"
[[ 9 -gt 10 ]]   && echo "  [[ 9 -gt 10 ]]   → TRUE" \
                 || echo "  [[ 9 -gt 10 ]]   → false (đúng)"
[[ 20 -gt 9 ]]   && echo "  [[ 20 -gt 9 ]]   → TRUE (đúng)" \
                 || echo "  [[ 20 -gt 9 ]]   → false"

echo ""
echo "Kết luận: dùng -gt/-lt/-eq cho số, == / != cho string"

echo ""
echo "=============================="
echo " Bài 5.3 — [ ] vs [[ ]] và word splitting"
echo "=============================="
echo ""

VAR="hello world"

echo "--- [ ] với biến chứa khoảng trắng (không quote) ---"
echo "  VAR=\"hello world\""
# shellcheck disable=SC2086
if [ -n $VAR ] 2>/dev/null; then
    echo '  [ -n $VAR ]  → true (may mắn hoặc lỗi tùy shell)'
else
    echo '  [ -n $VAR ]  → false hoặc lỗi'
fi
echo "  (Bash expand thành: [ -n hello world ] → 'too many arguments' trên nhiều hệ thống)"

echo ""
echo "--- [[ ]] với biến chứa khoảng trắng (không quote) ---"
# shellcheck disable=SC2086
if [[ -n $VAR ]]; then
    echo '  [[ -n $VAR ]] → TRUE (an toàn — bash không word-split bên trong [[)'
else
    echo '  [[ -n $VAR ]] → false'
fi

echo ""
EMPTY=""
echo "--- Biến rỗng: [ ] vs [[ ]] ---"
echo "  EMPTY=\"\""
# shellcheck disable=SC2086
[ -n $EMPTY ]   && echo '  [ -n $EMPTY ]   → true  (bug! [ -n ] thiếu arg → true)' \
                || echo '  [ -n $EMPTY ]   → false'
[[ -n $EMPTY ]] && echo '  [[ -n $EMPTY ]] → true' \
                || echo '  [[ -n $EMPTY ]] → false (đúng)'

echo ""
echo "Kết luận: luôn dùng [[ ]] trong bash script"
