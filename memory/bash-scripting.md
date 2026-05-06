# Bash Scripting — Production Patterns

## 1. Script Header

```bash
#!/usr/bin/env bash
set -euo pipefail
```

| Flag | Tên | Hành vi |
|------|-----|---------|
| `-e` | errexit | Thoát ngay khi bất kỳ lệnh nào trả về exit code ≠ 0 |
| `-u` | nounset | Lỗi ngay nếu dùng biến chưa khai báo (bắt typo) |
| `-o pipefail` | pipefail | Exit code của pipe = exit code của lệnh THẤT BẠI đầu tiên, không phải lệnh cuối |

`-e` bị **tắt tạm** trong vị trí điều kiện: `if cmd`, `while cmd`, `cmd &&`, `cmd ||`.

---

## 2. Input Validation

Ba pattern, chọn theo độ phức tạp:

```bash
# Pattern 1 — kiểm tra thủ công (linh hoạt nhất)
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <host> <env>" >&2
    exit 2
fi

# Pattern 2 — ${var:?msg} (ngắn gọn, inline)
HOST="${1:?Usage: $0 <host> <env>}"
ENV="${2:?Usage: $0 <host> <env>}"

# Pattern 3 — usage() function (chuẩn nhất, dùng khi có nhiều flag)
usage() {
    echo "Usage: $0 [-d] <host> <env>" >&2
    echo "  -d  dry-run" >&2
    exit 2
}
[[ ${1:-} == "-h" || ${1:-} == "--help" ]] && usage
[[ $# -lt 2 ]] && usage
```

Validate giá trị (không chỉ sự tồn tại):

```bash
die() { echo "ERROR: $*" >&2; exit 1; }

[[ $PORT =~ ^[0-9]+$ ]]                  || die "port phải là số: '$PORT'"
[[ $PORT -ge 1 && $PORT -le 65535 ]]     || die "port ngoài khoảng hợp lệ"
[[ $ENV =~ ^(dev|staging|production)$ ]] || die "env không hợp lệ: '$ENV'"
```

| Exit code | Ý nghĩa | Dùng khi |
|-----------|---------|----------|
| `0` | Thành công | Script làm đúng việc |
| `1` | Lỗi runtime | Host down, file mất, API lỗi |
| `2` | Bad args | Caller gọi script sai cách |
| `64–78` | sysexits.h | Tool/library errors (66=noinput, 69=unavailable, 77=noperm) |

---

## 3. Conditionals

### File tests — dùng `-f` thay `-e` cho files

```bash
[[ -f "$p" ]]   # regular file (không phải dir — quan trọng với log files)
[[ -d "$p" ]]   # directory
[[ -e "$p" ]]   # tồn tại (bất kỳ loại — tránh dùng cho files)
[[ -r "$p" ]]   # readable
[[ -w "$p" ]]   # writable
[[ -x "$p" ]]   # executable
[[ -s "$p" ]]   # tồn tại VÀ không rỗng
```

### String tests

```bash
[[ -z "$s" ]]          # rỗng (zero length)
[[ -n "$s" ]]          # không rỗng — [[ "$s" ]] cũng hoạt động
[[ "$s" == "abc" ]]    # bằng (chuỗi)
[[ "$s" != "abc" ]]    # khác
[[ "$s" == abc* ]]     # glob pattern (không quote pattern)
[[ "$s" =~ ^[0-9]+$ ]] # regex
```

### Number tests — KHÔNG dùng `<` `>` cho số trong `[[ ]]`

```bash
[[ $n -eq $m ]]   # bằng
[[ $n -ne $m ]]   # khác
[[ $n -lt $m ]]   # nhỏ hơn
[[ $n -le $m ]]   # nhỏ hơn hoặc bằng
[[ $n -gt $m ]]   # lớn hơn
[[ $n -ge $m ]]   # lớn hơn hoặc bằng
(( n > m ))       # cú pháp toán học thay thế
```

`<` `>` trong `[[ ]]` là so sánh **chuỗi theo ASCII** — `[[ 9 > 10 ]]` là TRUE.

### `[[ ]]` vs `[ ]`

| | `[ ]` | `[[ ]]` |
|-|-------|---------|
| Word splitting | Có — nguy hiểm | Không |
| Glob / Regex | Không | Có |
| `&&` `\|\|` bên trong | Không | Có |
| POSIX portable | Có | Bash only |

**Luôn dùng `[[ ]]`** khi shebang là `#!/usr/bin/env bash`. Luôn quote `"$var"`.

---

## 4. Functions

```bash
# Định nghĩa — dùng dạng POSIX (không dùng `function` keyword)
check_disk() {
    local threshold=${1:-80}    # local + default value
    local usage
    usage=$(df / | awk 'NR==2 {print $5+0}')   # tách local và gán (bảo toàn -e)
    (( usage <= threshold )) || return 1
}

# Return via exit code
if check_disk 90; then
    log "Disk OK"
else
    die "Disk quá đầy"
fi

# Capture output
get_instance_id() {
    local name=$1
    aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$name" \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text
}
INSTANCE_ID=$(get_instance_id "prod-api")
```

| Quy tắc | Lý do |
|---------|-------|
| `local var` trước khi gán | Biến không khai báo local sẽ leak thành global |
| Tách `local var` và `var=$(cmd)` thành 2 dòng | `local var=$(cmd)` che exit code của cmd — -e không kích hoạt |
| Constants dùng `readonly` | `readonly LOG=/var/log/app.log` — ngăn ghi đè |

### Cấu trúc script chuẩn

```
1. #!/usr/bin/env bash + set -euo pipefail
2. readonly CONSTANTS
3. log() err() die() usage()
4. domain functions (check_*, deploy_*, fetch_*)
5. main() { parse args → validate → run }
6. main "$@"   ← dòng cuối cùng
```

---

## 5. Output Handling

### File descriptors

| FD | Tên | Default | Dùng cho |
|----|-----|---------|----------|
| 0 | stdin | bàn phím | đọc input |
| 1 | stdout | terminal | output bình thường |
| 2 | stderr | terminal | lỗi, warnings, usage |

### Redirect patterns

```bash
cmd > out.log          # stdout → file, stderr → terminal
cmd 2> err.log         # stderr → file, stdout → terminal
cmd > out.log 2>&1     # cả hai → file (THỨ TỰ QUAN TRỌNG)
cmd 2>&1 > out.log     # SAI: stderr → terminal, stdout → file
cmd &> all.log         # bash shorthand cho 2>&1
cmd 2>/dev/null        # bỏ stderr, giữ stdout
cmd &>/dev/null        # bỏ cả hai
```

`2>&1` nghĩa là "fd 2 trỏ tới chỗ fd 1 **đang trỏ lúc này**" — phải set `> file` trước.

### Helper functions

```bash
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] INFO  $*"; }
err() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR $*" >&2; }
die() { err "$@"; exit 1; }
```

### Capture output + exit code

```bash
# if output=$(...) — -e bị tắt trong vị trí điều kiện
if response=$(curl -sS --max-time 5 "$URL"); then
    echo "$response" | jq .
else
    die "curl thất bại: $URL"
fi
```

### `|| true` — khi nào OK

```bash
rm -rf /tmp/build || true          # OK: cleanup idempotent
kubectl delete ns old-env || true  # OK: có thể đã xóa rồi
kubectl apply -f manifests/ || true  # NGUY HIỂM: che lỗi deploy
```

---

## 6. PATH Hygiene

### Vấn đề

Cron và CI runner dùng PATH tối giản (`/usr/bin:/bin`). `~/.bashrc`, `~/.zshrc`, asdf shims **KHÔNG chạy**.
Tool cài ở `/opt/homebrew/bin` hay `~/.local/bin` → **không tìm thấy**.

### Preflight check pattern (cách tốt nhất)

```bash
check_prerequisites() {
    local missing=()
    for cmd in jq curl aws kubectl; do
        command -v "$cmd" >/dev/null || missing+=("$cmd")
    done
    (( ${#missing[@]} == 0 )) || die "Thiếu tool: ${missing[*]}"
}
```

`command -v` thay vì `which`:

| | `which` | `command -v` |
|-|---------|--------------|
| Loại | External binary | Bash built-in |
| Exit code | Không đáng tin (một số hệ thống exit 0 dù không tìm thấy) | Luôn đáng tin |
| POSIX | Không | Có |

### Cron — cấu hình đầu crontab

```cron
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin
MAILTO=ttrungtin.work@gmail.com
0 2 * * * /home/tin/scripts/backup.sh >> /var/log/backup.log 2>&1
```

### Working directory trong cron

```bash
# Dùng SCRIPT_DIR thay relative paths — an toàn trong cron
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/manifests/deploy.yaml"
```

---

## 7. shellcheck

Cài đặt:

```bash
# Ubuntu/Debian
sudo apt-get install shellcheck

# macOS
brew install shellcheck

# CI (GitHub Actions)
- uses: ludeeus/action-shellcheck@master
```

Chạy:

```bash
shellcheck scripts/healthcheck.sh          # kiểm tra một file
shellcheck scripts/*.sh                    # kiểm tra tất cả
shellcheck -x scripts/healthcheck.sh       # follow sourced files
shellcheck --severity=warning scripts/*.sh # chỉ warning trở lên
```

Tích hợp vào git hook (chạy trước commit):

```bash
# .git/hooks/pre-commit
#!/usr/bin/env bash
set -euo pipefail
if command -v shellcheck >/dev/null; then
    shellcheck scripts/*.sh
fi
```

Các lỗi shellcheck phổ biến và cách sửa:

| Code | Vấn đề | Cách sửa |
|------|--------|----------|
| SC2086 | `$var` không được quote | Đổi thành `"$var"` |
| SC2046 | `$(cmd)` không được quote | Đổi thành `"$(cmd)"` |
| SC2155 | `local var=$(cmd)` — che exit code | Tách thành 2 dòng |
| SC2034 | Biến khai báo nhưng không dùng | Xóa hoặc thêm `# shellcheck disable` |
| SC2164 | `cd` không kiểm tra lỗi | Dùng `cd /path || die "..."` |
