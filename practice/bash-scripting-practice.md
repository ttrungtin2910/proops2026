# Bash Scripting — Bài Tập Thực Hành

Tương ứng với `memory/bash-scripting.md`. Làm theo thứ tự — mỗi phần build lên phần trước.

---

## Phần 1 — Exit Codes và `set -euo pipefail`

### Bài 1.1 — Quan sát hành vi không có `set -e`

Tạo `practice/01-no-set-e.sh`:

```bash
#!/usr/bin/env bash
# KHÔNG có set -e

mkdir /protected-dir
cd /protected-dir
echo "Tôi đang ở: $(pwd)"
echo "Script kết thúc với exit code: $?"
```

Chạy và trả lời:
- Script có dừng khi `mkdir` thất bại không?
- `echo "Tôi đang ở: $(pwd)"` in ra thư mục nào?
- Exit code cuối cùng của script là bao nhiêu? (`echo $?` sau khi chạy)

**✓ Pass:** Thấy được script chạy hết dù có lỗi, in thư mục sai, exit code là 0.

---

### Bài 1.2 — Thêm `set -e`, quan sát sự khác biệt

Sao chép `01-no-set-e.sh` thành `02-with-set-e.sh`, thêm `set -e` vào dòng 2. Chạy lại:

- Script dừng ở dòng nào?
- Exit code là bao nhiêu?

**✓ Pass:** Script dừng ngay tại `mkdir`, không bao giờ chạy đến `echo "Tôi đang ở..."`.

---

### Bài 1.3 — Bẫy `pipefail`

Tạo `practice/03-pipefail.sh`:

```bash
#!/usr/bin/env bash

echo "=== Không có pipefail ==="
set -e
cat /file-khong-ton-tai | wc -l
echo "Dòng này có chạy không?"

echo "=== Có pipefail ==="
set -eo pipefail
cat /file-khong-ton-tai | wc -l
echo "Dòng này có chạy không?"
```

Chạy và ghi lại exit code của từng block. Giải thích tại sao block đầu cho phép `echo` chạy.

**✓ Pass:** Giải thích được `wc -l` exit 0 che lỗi của `cat` khi không có `pipefail`.

---

### Bài 1.4 — `timeout` bounded ping

Chạy từng lệnh, đo thời gian thực tế:

```bash
time ping -c 1 192.0.2.1
time timeout 3 ping -c 1 192.0.2.1
time ping -W 2 -c 1 192.0.2.1
```

Ghi lại: thời gian chờ, exit code (`echo $?` ngay sau mỗi lệnh), mã 124 nghĩa là gì.

**✓ Pass:** Phân biệt được 3 exit code khác nhau và thời gian chờ khác nhau.

---

## Phần 2 — Strict-Mode vs Explicit Error Handling

### Bài 2.1 — `if cmd` không kích hoạt `-e`

Tạo `practice/04-if-suppresses-e.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Trước if"
if ping -c 1 -W 1 192.0.2.1 &>/dev/null; then
    echo "Host online"
else
    echo "Host offline — nhưng script tiếp tục"
fi
echo "Sau if — script vẫn chạy"
```

**Câu hỏi thêm:** Thay `if ping...` bằng lệnh `ping` đứng một mình (không có `if`). Điều gì xảy ra? Thử nghiệm để xác nhận.

**✓ Pass:** Thấy được với `if` script tiếp tục, không có `if` script dừng.

---

### Bài 2.2 — Capture output + exit code

Tạo `practice/05-capture-output.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

URL="https://httpbin.org/status/404"

if response=$(curl -sS --fail --max-time 5 "$URL"); then
    echo "Thành công: $response"
else
    exit_code=$?
    echo "curl thất bại (exit $exit_code)" >&2
fi
```

Sau khi chạy xong, bổ sung thêm: capture HTTP status code bằng `-w "%{http_code}"` và kiểm tra `[[ "$code" == "200" ]]`.

**✓ Pass:** Script không crash, phân biệt được "curl thất bại" và "curl thành công nhưng trả về 4xx".

---

### Bài 2.3 — `|| true` đúng và sai chỗ

Tạo `practice/06-or-true.sh`, đánh dấu từng dòng là `OK` hay `NGUY HIỂM` bằng comment:

```bash
#!/usr/bin/env bash
set -euo pipefail

rm -rf /tmp/test-cleanup-$$ || true
kubectl delete ns non-existent || true
kubectl apply -f /tmp/broken.yaml || true
grep "pattern" /tmp/nonexistent.log || true
```

Viết 1 dòng comment giải thích lý do cho từng cái.

**✓ Pass:** Giải thích đúng tại sao `apply` không nên dùng `|| true`.

---

## Phần 3 — Input Validation

### Bài 3.1 — Ba pattern validation

Tạo `practice/07-validation.sh` nhận 2 argument `<host> <port>`, implement cả 3 pattern:

```bash
#!/usr/bin/env bash
set -euo pipefail

# TODO Pattern 1: kiểm tra $# thủ công

# TODO Pattern 2: ${var:?msg}

# TODO Pattern 3: usage() function

# TODO Validate giá trị: port phải là số, trong khoảng 1-65535

echo "OK: $HOST:$PORT"
```

Test tất cả trường hợp:

```bash
bash practice/07-validation.sh                  # thiếu cả hai arg
bash practice/07-validation.sh myhost           # thiếu port
bash practice/07-validation.sh myhost abc       # port không phải số
bash practice/07-validation.sh myhost 99999     # port ngoài khoảng
bash practice/07-validation.sh myhost 8080      # hợp lệ
```

**✓ Pass:** Mỗi case cho thông báo và exit code đúng. Case hợp lệ exit 0, lỗi arg exit 2, lỗi giá trị exit 1.

---

### Bài 3.2 — Phân biệt exit 1 và exit 2

Tạo `practice/08-exit-codes.sh` nhận `<env>` (dev/staging/production):

- Thiếu argument → exit 2
- Env không hợp lệ (vd: "uat") → exit 2
- Env hợp lệ nhưng giả lập không kết nối được → exit 1
- Thành công → exit 0

Tạo thêm `practice/08-caller.sh` gọi script trên và bắt từng trường hợp bằng `case $? in`.

**✓ Pass:** Caller phân biệt được "tôi gọi sai" (exit 2) vs "tool thất bại khi chạy" (exit 1).

---

## Phần 4 — Stream Redirection

### Bài 4.1 — Quan sát stdout vs stderr

Chạy từng lệnh và quan sát cái gì hiện trên terminal, cái gì trong file:

```bash
ls /tmp /nonexistent > /tmp/out.txt
cat /tmp/out.txt

ls /tmp /nonexistent 2> /tmp/err.txt
cat /tmp/err.txt

ls /tmp /nonexistent > /tmp/out.txt 2>&1
cat /tmp/out.txt

ls /tmp /nonexistent 2>&1 > /tmp/out.txt   # thứ tự ngược
cat /tmp/out.txt
```

Vẽ sơ đồ (dùng text/ASCII) cho 2 case cuối: `fd1 → đâu`, `fd2 → đâu`.

**✓ Pass:** Giải thích được tại sao case 3 và case 4 cho kết quả khác nhau.

---

### Bài 4.2 — curl và stderr

```bash
curl https://httpbin.org/get > /tmp/curl-out.txt
# Progress bar hiện trên terminal không? Tại sao?

curl https://httpbin.org/get > /tmp/curl-out.txt 2>/dev/null
# Progress bar biến mất — nó đang đi đâu?

curl -s https://httpbin.org/get > /tmp/curl-out.txt
# Khác gì 2>/dev/null?

curl -sS https://httpbin.org/status/404 > /tmp/curl-out.txt
# Lỗi HTTP có hiện ra không?
```

**✓ Pass:** Giải thích được `-s` tắt progress bar vì nó là stderr, và `-sS` giữ lại error messages.

---

### Bài 4.3 — Thêm log/err vào script cũ

Lấy `practice/07-validation.sh` từ Bài 3.1, thay tất cả `echo` bằng `log()`, `err()`, hoặc `die()` phù hợp:

- Thông báo lỗi → `err()`
- Usage message → `err()` (stderr)
- Thông tin bình thường → `log()`
- Fatal error + exit → `die()`

Verify:

```bash
bash practice/07-validation.sh 2>/dev/null
# Chỉ còn stdout — thông báo lỗi không hiện ra nữa
```

**✓ Pass:** Redirect `2>/dev/null` ẩn tất cả thông báo lỗi, chỉ giữ output hữu ích.

---

## Phần 5 — Conditional Checks

### Bài 5.1 — File tests

Tạo `practice/09-file-tests.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

check_file() {
    local path=$1
    echo "=== $path ==="
    [[ -e "$path" ]] && echo "  -e: tồn tại"        || echo "  -e: không tồn tại"
    [[ -f "$path" ]] && echo "  -f: là regular file" || echo "  -f: không phải regular file"
    [[ -d "$path" ]] && echo "  -d: là directory"    || echo "  -d: không phải directory"
    [[ -r "$path" ]] && echo "  -r: readable"        || echo "  -r: không readable"
    [[ -x "$path" ]] && echo "  -x: executable"      || echo "  -x: không executable"
    [[ -s "$path" ]] && echo "  -s: không rỗng"      || echo "  -s: rỗng hoặc không tồn tại"
}

check_file "/etc/passwd"
check_file "/tmp"
check_file "/usr/bin/curl"
```

Câu hỏi: tại sao nên dùng `-f` thay `-e` khi mong đợi một regular file?

**✓ Pass:** Giải thích được `/tmp` trả về `-d true` nhưng `-f false`, và nguy hiểm của `-e` với log files.

---

### Bài 5.2 — Bẫy so sánh số bằng string operator

Chạy từng dòng, giải thích kết quả:

```bash
[[ "9" > "10" ]]  && echo "9 lớn hơn 10 (string)" || echo "9 không lớn hơn 10"
[[ 9 -gt 10 ]]    && echo "9 lớn hơn 10 (số)"     || echo "9 không lớn hơn 10"

[[ "20" > "9" ]]  && echo "20 lớn hơn 9 (string)" || echo "20 không lớn hơn 9"
[[ 20 -gt 9 ]]    && echo "20 lớn hơn 9 (số)"     || echo "20 không lớn hơn 9"
```

**✓ Pass:** Giải thích được `"20" < "9"` theo ASCII vì so sánh ký tự đầu tiên `"2" < "9"`.

---

### Bài 5.3 — `[[ ]]` vs `[ ]` — word splitting

```bash
VAR="hello world"
[ -n $VAR ]    && echo "[ ] thấy non-empty"  || echo "[ ] lỗi hoặc empty"
[[ -n $VAR ]]  && echo "[[ ]] thấy non-empty" || echo "[[ ]] thấy empty"

EMPTY=""
[ -n $EMPTY ]   && echo "[ ] thấy non-empty" || echo "[ ] thấy empty"
[[ -n $EMPTY ]] && echo "[[ ]] thấy non-empty" || echo "[[ ]] thấy empty"
```

Giải thích tại sao `[ -n $VAR ]` với `VAR="hello world"` cho lỗi "too many arguments".

**✓ Pass:** Hiểu word splitting là lý do luôn dùng `[[ ]]` trong bash.

---

## Phần 6 — Script Structure

### Bài 6.1 — `local` variable leak

Tạo `practice/10-local-leak.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

process_without_local() {
    result="processed: $1"   # global!
}

process_with_local() {
    local result
    result="processed: $1"
}

result="giá trị quan trọng"
process_without_local "input"
echo "Sau without_local: result = '$result'"

result="giá trị quan trọng"
process_with_local "input"
echo "Sau with_local:    result = '$result'"
```

**✓ Pass:** Thấy rõ `without_local` ghi đè biến global, `with_local` không.

---

### Bài 6.2 — `local var=$(cmd)` che exit code

Tạo `practice/11-local-exitcode.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

bad_function() {
    local result=$(cat /file-khong-ton-tai)   # một dòng — lỗi bị che
    echo "bad_function chạy tiếp: '$result'"
}

good_function() {
    local result
    result=$(cat /file-khong-ton-tai)         # hai dòng — -e bắt được
    echo "good_function chạy tiếp: '$result'"
}

echo "=== bad_function ==="
bad_function && echo "kết thúc bình thường" || echo "thất bại: $?"

echo "=== good_function ==="
good_function && echo "kết thúc bình thường" || echo "thất bại: $?"
```

**✓ Pass:** `bad_function` tiếp tục chạy dù lệnh con thất bại. `good_function` dừng đúng chỗ.

---

### Bài 6.3 — Viết script cấu trúc chuẩn

Viết `practice/12-structured.sh` kiểm tra xem một domain có phản hồi HTTP không. Phải có đúng thứ tự:

```
1. shebang + set -euo pipefail
2. readonly constants (TIMEOUT, MAX_RETRIES)
3. log() err() die() usage()
4. check_prerequisites()
5. check_domain()
6. main() — chỉ parse args, validate, gọi functions
7. main "$@"
```

Kiểm tra:

```bash
shellcheck practice/12-structured.sh     # phải clean
bash practice/12-structured.sh --help    # hiện usage
bash practice/12-structured.sh           # thiếu arg, exit 2
bash practice/12-structured.sh google.com
```

**✓ Pass:** `shellcheck` không warning. `--help` hiện usage. Cấu trúc đúng thứ tự.

---

## Phần 7 — PATH Hygiene

### Bài 7.1 — Simulate môi trường cron

```bash
echo "PATH hiện tại:"
echo $PATH

echo ""
echo "PATH trong cron:"
env -i PATH=/usr/bin:/bin HOME=$HOME bash -c 'echo $PATH'

echo ""
echo "Tìm tool trong PATH cron:"
env -i PATH=/usr/bin:/bin HOME=$HOME bash -c 'command -v jq 2>&1 || echo "jq: NOT FOUND"'
env -i PATH=/usr/bin:/bin HOME=$HOME bash -c 'command -v aws 2>&1 || echo "aws: NOT FOUND"'
env -i PATH=/usr/bin:/bin HOME=$HOME bash -c 'command -v kubectl 2>&1 || echo "kubectl: NOT FOUND"'
```

Liệt kê 2 tool bạn thường dùng mà không có trong `/usr/bin:/bin` và đường dẫn thật của chúng.

**✓ Pass:** Liệt kê được ít nhất 2 tool và giải thích tại sao chúng fail trong cron.

---

### Bài 7.2 — Preflight check pattern

Thêm `check_prerequisites()` vào `practice/12-structured.sh` từ Bài 6.3. Kiểm tra `curl`, `jq`, và một tool không tồn tại (`notexist-tool`):

```bash
check_prerequisites() {
    local missing=()
    for cmd in curl jq notexist-tool; do
        command -v "$cmd" >/dev/null || missing+=("$cmd")
    done
    (( ${#missing[@]} == 0 )) || die "Thiếu tool: ${missing[*]}"
}
```

**✓ Pass:** Script in ra tên tool thiếu và exit 1, không crash với "command not found" ở giữa chừng.

---

### Bài 7.3 — SCRIPT_DIR pattern

Tạo `practice/13-scriptdir.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "CWD:        $(pwd)"
echo "SCRIPT_DIR: $SCRIPT_DIR"
echo "Relative:   ../test-relative.txt  → sẽ tạo ở $(pwd)/../test-relative.txt"
echo "Absolute:   $SCRIPT_DIR/../test-absolute.txt  → luôn đúng"
```

Chạy từ hai thư mục khác nhau:

```bash
cd /tmp && bash ~/proops2026/practice/13-scriptdir.sh
cd ~/proops2026 && bash practice/13-scriptdir.sh
```

**✓ Pass:** `SCRIPT_DIR` luôn cùng giá trị dù gọi từ đâu. CWD thay đổi. Hiểu khi nào dùng cái nào.

---

## Bài Tổng Hợp — Script Hoàn Chỉnh

Viết `practice/14-deploy-check.sh` từ đầu (không copy từ `scripts/healthcheck.sh`).

**Yêu cầu chức năng:**
- Nhận `<cluster> <namespace>` làm argument, flag `-d` cho dry-run
- Kiểm tra `kubectl` và `aws` có trong PATH
- Kiểm tra cluster có kết nối không (`kubectl cluster-info`)
- Kiểm tra namespace có tồn tại không, nếu không thì tạo
- Log mỗi bước với timestamp
- Dry-run mode: in lệnh sẽ chạy nhưng không thực thi

**Checklist kỹ thuật — tự đánh dấu trước khi nộp:**

```
[ ] set -euo pipefail ở dòng 2
[ ] readonly constants
[ ] log() err() die() usage() helpers
[ ] check_prerequisites() với command -v loop
[ ] usage() exit 2, die() exit 1
[ ] local vars trong mỗi function, tách local và gán thành 2 dòng
[ ] if cmd; then cho expected failures (cluster check)
[ ] || true chỉ ở những chỗ hợp lý
[ ] 2>/dev/null hoặc &>/dev/null đúng chỗ
[ ] main() chỉ orchestrate — không chứa logic chi tiết
[ ] main "$@" ở dòng cuối cùng
[ ] shellcheck không warning
```

**Test cases phải pass:**

```bash
bash practice/14-deploy-check.sh                        # exit 2, hiện usage
bash practice/14-deploy-check.sh --help                 # exit 2, hiện usage
bash practice/14-deploy-check.sh prod-cluster           # exit 2, thiếu namespace
bash practice/14-deploy-check.sh -d prod-cluster apps   # dry-run, in lệnh
shellcheck practice/14-deploy-check.sh                  # clean, không warning
```

**✓ Pass:** Tất cả test cases cho exit code và output đúng. shellcheck clean.

---

## Tổng Kết

| Phần | Bài | Kỹ năng |
|------|-----|---------|
| 1 | 1.1–1.4 | exit code, set -e, pipefail, timeout |
| 2 | 2.1–2.3 | if vs -e, capture output, \|\| true |
| 3 | 3.1–3.2 | $#, ${:?}, usage(), die(), exit 1 vs 2 |
| 4 | 4.1–4.3 | fd 0/1/2, redirect patterns, log/err |
| 5 | 5.1–5.3 | file/string/number tests, [[ ]] vs [ ] |
| 6 | 6.1–6.3 | local, return via exit code, script structure |
| 7 | 7.1–7.3 | PATH cron, command -v, SCRIPT_DIR |
| Tổng hợp | 14 | Tất cả patterns trong một script |
