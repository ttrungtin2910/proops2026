# Daily Log — Tin (Trần Trung Tín) — Day 17 — 06 May 2026

## Today's Assignment (Day 17 — Bash Scripting: From Manual Commands to Production-Safe Scripts)
- [x] Q1 — Exit codes: what `$?` is, 0 vs non-zero, capture before next command overwrites
- [x] Q2 — `set -e` behavior: without it, bash silently continues on failure; with it, script exits immediately
- [x] Q3 — `set -euo pipefail` canonical header: what each flag closes, why pipefail catches silent pipe failures
- [x] Q4 — Strict mode vs explicit error handling: when `if cmd; then` suppresses `-e` and when to let `-e` exit
- [x] Q5 — Input validation patterns: `$#`, `${var:?msg}`, `usage()` function, `die()`, exit 1 vs exit 2
- [x] Q6 — Stream redirection: fd 0/1/2, redirect patterns, `2>&1` order, `curl -s` vs `-sS`
- [x] Q7 — Conditional checks: file tests (`-f -d -e -r -w -s`), string tests, number tests, `[[ ]]` vs `[ ]`
- [x] Q8 — Script structure: function syntax, `local` vars, return via exit code, standard section order, comments
- [x] Q9 — PATH hygiene: cron/CI minimal PATH, preflight check pattern, `command -v` vs `which`, SCRIPT_DIR
- [x] Q10 — Artifacts: `memory/bash-scripting.md`, `scripts/healthcheck.sh`, `practice/bash-scripting-practice.md`, 18 practice scripts

## Environment
Windows 11 Pro, Claude Code CLI inside VSCode. WSL (Ubuntu) for running `.sh` files. Bash 5.x. No cloud resources used today — local scripting session. `shellcheck` available via WSL for script validation.

---

## Completed

- [x] **Q1 — Exit codes and `$?`:**

  Every command exits with a numeric code stored in `$?`. Shell reads it before the next command overwrites it.

  | Code | Meaning | Who returns it |
  |------|---------|---------------|
  | `0` | Success | Any successful command |
  | `1` | General error | Runtime failures |
  | `2` | Misuse (bad args) | bash built-ins, CLI tools, `usage()` |
  | `126` | Not executable | Shell (permission denied on run) |
  | `127` | Command not found | Shell (not in `$PATH`) |
  | `128+N` | Killed by signal N | Shell (130=Ctrl+C, 137=kill -9) |

  **Key pattern:** capture `$?` immediately — the next command overwrites it.
  ```bash
  curl -sf https://api.example.com/health
  STATUS=$?    # capture before anything else runs
  if [[ $STATUS -ne 0 ]]; then
      echo "Health check failed: $STATUS"
      exit 1
  fi
  ```

- [x] **Q2 — `set -e`: silent failure cascade vs early exit:**

  Without `set -e`, bash ignores errors and continues — the script "succeeds" while doing real damage.

  **The danger:**
  ```bash
  mkdir /protected-dir     # FAILS (permission denied)
  cd /protected-dir        # still runs! stays in original dir
  cp config.json .         # still runs! copies to wrong place
  systemctl restart myapp  # still runs! restarts with bad config
  echo "Done."             # exits 0 — lies about success
  ```

  With `set -e`: script stops at `mkdir`. No subsequent damage. CI pipeline goes red.

  Observed in practice (Bài 1.1 vs 1.2): `01-no-set-e.sh` ran all 5 lines and exited 0. `02-with-set-e.sh` stopped at line 4, CI got non-zero exit.

- [x] **Q3 — `set -euo pipefail` canonical header:**

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  ```

  | Flag | Danger it closes | Real example |
  |------|-----------------|-------------|
  | `-e` | Silent failure cascade | `mkdir` fails → rest of script runs on wrong path |
  | `-u` | Typo variable name | `$ENVI` instead of `$ENV` → deploy to empty namespace |
  | `-o pipefail` | Pipe reports success even if first cmd fails | `pg_dump mydb \| gzip > backup.gz` succeeds even if `pg_dump` crashes |

  **`pipefail` experiment (Bài 1.3):**
  Without `pipefail`: `cat /nonexistent | wc -l` → pipe exits 0 (wc succeeded). `echo` runs.
  With `pipefail`: pipe exits 1 (cat failed). `echo` never runs. `-e` stops the script.

  **Timeout-bounded ping (Bài 1.4):**
  ```bash
  time ping -c 1 192.0.2.1          # waits ~20s, exit 1
  time timeout 3 ping -c 1 192.0.2.1 # exits after 3s, exit 124
  time ping -W 2 -c 1 192.0.2.1     # per-packet 2s, exit 1
  ```
  `timeout` exit code 124 = timed out. Use `timeout` for any network call in CI to prevent pipeline hangs.

- [x] **Q4 — Strict mode vs explicit error handling:**

  **Key insight:** `-e` is suppressed in condition positions. `if cmd`, `while cmd`, `cmd &&`, `cmd ||` all suppress `-e` for the test command.

  ```bash
  # -e suppressed — bash expects the command might fail
  if ping -c 1 -W 2 host &>/dev/null; then
      echo "online"
  else
      echo "offline"   # script continues
  fi
  ```

  **Decision table:**
  | Situation | Pattern | Reason |
  |-----------|---------|--------|
  | File might not exist, have fallback | `if [[ -f ... ]]` | Expected branch |
  | Host might be down, have replica | `if ping ...; then` | Expected branch |
  | Required tool not installed | Let `-e` exit | Script can't continue |
  | Required argument missing | `${VAR:?msg}` or `usage()` | Script is being misused |
  | Deploy/apply step fails | Let `-e` exit | Continuing = damage |

  **Capture output + exit code together (Bài 2.2):**
  ```bash
  # if output=$(...) — -e suppressed in condition position
  if response=$(curl -sS --max-time 5 "$URL"); then
      echo "$response" | jq .status
  else
      die "fetch failed: $URL"
  fi
  ```

  **`|| true` rules:**
  - OK: `rm -rf /tmp/build || true` (cleanup, idempotent)
  - OK: `kubectl delete ns old-env || true` (might already be gone)
  - DANGEROUS: `kubectl apply -f manifests/ || true` (hides deploy failures)

- [x] **Q5 — Input validation patterns:**

  Three patterns — choose by complexity:

  ```bash
  # Pattern 1: manual $# check
  if [[ $# -lt 2 ]]; then
      echo "Usage: $0 <host> <port>" >&2; exit 2
  fi

  # Pattern 2: ${var:?msg} — inline, short
  HOST="${1:?Usage: $0 <host> <port>}"
  PORT="${2:?Usage: $0 <host> <port>}"

  # Pattern 3: usage() function — best for multiple flags
  usage() { echo "Usage: $0 [-d] <host> <port>" >&2; exit 2; }
  [[ ${1:-} == "--help" ]] && usage
  [[ $# -lt 2 ]] && usage
  ```

  **Value validation (not just presence):**
  ```bash
  die() { echo "ERROR: $*" >&2; exit 1; }
  [[ $PORT =~ ^[0-9]+$ ]]              || die "port must be integer: '$PORT'"
  [[ $PORT -ge 1 && $PORT -le 65535 ]] || die "port out of range: $PORT"
  [[ $ENV =~ ^(dev|staging|production)$ ]] || die "invalid env: '$ENV'"
  ```

  **Exit code convention:**
  - `exit 2` = caller misused the script (bad args, wrong syntax)
  - `exit 1` = tool failed at runtime (host down, file missing, API error)
  - Distinction lets calling scripts route "fix the code" vs "retry" separately

  **Implemented in `practice/07-validation.sh`** — 10 test cases all passing:

  | Input | Exit | Reason |
  |-------|------|--------|
  | (no args) | 2 | `$# -lt 2` → `usage()` |
  | `myhost` only | 2 | `$# -lt 2` → `usage()` |
  | `myhost abc` | 1 | regex `^[0-9]+$` fails |
  | `myhost 99999` | 1 | `-le 65535` fails |
  | `myhost 8080` | 0 | all checks pass |
  | `--help` | 2 | `usage()` |

- [x] **Q6 — Stream redirection:**

  | Pattern | fd1 destination | fd2 destination |
  |---------|----------------|----------------|
  | `cmd > file` | file | terminal |
  | `cmd 2> file` | terminal | file |
  | `cmd > file 2>&1` | file | file (correct) |
  | `cmd 2>&1 > file` | file | terminal (wrong order!) |
  | `cmd &> file` | file | file (bash shorthand) |
  | `cmd 2>/dev/null` | terminal | discarded |

  **Why order matters in `> file 2>&1`:**
  `2>&1` means "make fd2 point to wherever fd1 currently points". Shell processes left-to-right:
  - `> file` first → fd1 = file
  - `2>&1` after → fd2 = "where fd1 is now" = file ✓

  Reversed (`2>&1 > file`): fd2 = "where fd1 is now" = terminal. Then fd1 = file. fd2 stays on terminal.

  **curl and stderr:**
  Progress bar goes to stderr by design (so stdout stays clean for piping).
  - `-s`: silent — suppresses progress AND error messages
  - `-sS`: silent + Show-errors — suppresses progress, keeps errors on stderr
  Use `-sS` in scripts: clean output, still see failures.

  **`log()` and `err()` helpers:**
  ```bash
  log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] INFO  $*"; }
  err() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR $*" >&2; }
  die() { err "$@"; exit 1; }
  ```
  Timestamps + stderr split for free. Running `./script.sh 2>/dev/null` cleanly strips all errors.

- [x] **Q7 — Conditional checks:**

  **File tests — use `-f` not `-e` for files:**
  ```bash
  [[ -f "$p" ]]  # regular file (not dir — critical for log files)
  [[ -d "$p" ]]  # directory
  [[ -e "$p" ]]  # exists (any type — avoid for files)
  [[ -r "$p" ]]  # readable
  [[ -w "$p" ]]  # writable
  [[ -x "$p" ]]  # executable
  [[ -s "$p" ]]  # exists AND non-empty
  ```
  Why `-f` over `-e`: if `/var/log/app.log` is accidentally a directory, `-e` returns true and `while read` fails with a confusing error. `-f` catches it.

  **Number comparison trap (Bài 5.2):**
  ```bash
  [[ "9" > "10" ]]  # TRUE — "9" > "1" by ASCII
  [[ 9 -gt 10 ]]    # false — correct numeric comparison
  [[ "20" > "9" ]]  # FALSE — "2" < "9" by ASCII
  [[ 20 -gt 9 ]]    # TRUE  — correct
  ```
  Never use `<` `>` for numbers in `[[ ]]`. Always use `-gt -lt -ge -le -eq -ne`.

  **`[[ ]]` vs `[ ]` (Bài 5.3):**
  ```bash
  VAR="hello world"
  [ -n $VAR ]    # bash: [ -n hello world ]: too many arguments — DANGEROUS
  [[ -n $VAR ]]  # safe — bash does not word-split inside [[
  ```
  Always `[[ ]]` in `#!/usr/bin/env bash` scripts.

- [x] **Q8 — Script structure:**

  **`local` variable leak (Bài 6.1):**
  Without `local`, function variables pollute global scope — a refactor in function A silently breaks caller B two weeks later.

  **`local var=$(cmd)` hides exit code (Bài 6.2):**
  ```bash
  # BAD — exit code of 'local' = 0, hides cmd failure
  local result=$(failing_cmd)

  # GOOD — -e catches failing_cmd
  local result
  result=$(failing_cmd)
  ```
  `bad_function` in `11-local-exitcode.sh` continued past `cat /nonexistent`. `good_function` stopped correctly.

  **Standard section order:**
  ```
  1. #!/usr/bin/env bash + set -euo pipefail
  2. readonly CONSTANTS
  3. log() err() die() usage()
  4. domain functions (check_*, deploy_*, fetch_*)
  5. main() — orchestrates, no raw logic
  6. main "$@"   ← last line always
  ```

  **Comment rule:** comment WHY, not WHAT.
  ```bash
  # BAD:  # get disk usage
  usage=$(df / | awk 'NR==2 {print $5+0}')

  # GOOD: # $5+0 coerces "83%" string to integer 83 in awk
  usage=$(df / | awk 'NR==2 {print $5+0}')
  ```

- [x] **Q9 — PATH hygiene for cron/CI:**

  Cron minimal PATH: `/usr/bin:/bin`. CI runner (GitHub Actions ubuntu-latest): `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`.
  `~/.bashrc`, `~/.zshrc`, asdf shims, homebrew paths — **none of these run in cron/CI**.

  **Three fixes ranked:**
  1. Worst: hardcode `/opt/homebrew/bin/jq` — breaks on Linux, teammates' machines
  2. Middle: `export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"` — partial fix
  3. Best: preflight check — fails early with clear message:

  ```bash
  check_prerequisites() {
      local missing=()
      for cmd in jq curl aws kubectl; do
          command -v "$cmd" >/dev/null || missing+=("$cmd")
      done
      (( ${#missing[@]} == 0 )) || die "missing tools: ${missing[*]}"
  }
  ```

  **`command -v` vs `which`:** `which` is an external binary with inconsistent exit codes across systems. `command -v` is a bash built-in, POSIX-portable, exit code always reliable.

  **SCRIPT_DIR pattern (Bài 7.3):**
  ```bash
  readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ```
  Relative paths (`./manifests/`) change based on CWD at call time. `$SCRIPT_DIR/manifests/` is always the directory next to the script — safe in cron, CI, and symlinked installs.

  **Cron template:**
  ```cron
  SHELL=/bin/bash
  PATH=/usr/local/bin:/usr/bin:/bin
  MAILTO=ttrungtin.work@gmail.com
  0 2 * * * /home/tin/scripts/backup.sh >> /var/log/backup.log 2>&1
  ```

- [x] **Q10 — Artifacts built:**

  All artifacts described in next section.

---

## Not Completed
| Item | Reason |
|------|--------|
| `practice/12-structured.sh` (full implementation) | Skeleton only — left as exercise for self-practice |
| `practice/14-deploy-check.sh` (full implementation) | Skeleton only — capstone exercise |
| shellcheck validation on all practice scripts | WSL path issue prevented automated run; manual check deferred |

---

## Extra Things Explored

- **`set -e` in functions called from `if`:** if you wrap a function call in `if my_func; then`, `-e` is suppressed inside `my_func` too — not just at the call site. This means a failing command inside the function won't abort the script. Important to know when writing functions that are sometimes called unconditionally and sometimes from `if`.

- **`(( ))` vs `[[ ]]` for numbers:** `(( ))` is an arithmetic context — supports C-style operators `>`, `<`, `==`, `++`, `+=`. Cleaner than `-gt`, `-lt` flags. `(( count++ ))` works. `[[ count++ ]]` does not. For pure numeric work, `(( ))` is preferred; for mixed file/string/number conditions, `[[ ]]` with `-gt` is cleaner.

- **`BASH_SOURCE[0]` vs `$0`:** `$0` is the name of the script as invoked (relative or absolute, depending on how it was called). `${BASH_SOURCE[0]}` is always the path to the file containing the code, even when the file is sourced with `. script.sh` or `source script.sh`. For `SCRIPT_DIR`, always use `${BASH_SOURCE[0]}`.

- **`shellcheck SC2155`:** `local var=$(cmd)` is exactly the pattern shellcheck SC2155 flags. Running `shellcheck` before commit would have caught this automatically. shellcheck is the bash equivalent of a type checker — it catches ~80% of common bash bugs statically.

---

## Artifacts Built Today

- [x] `memory/bash-scripting.md` — 7-section reference: header pattern, input validation, conditionals table, functions, output/redirect, PATH hygiene, shellcheck. Tables and code blocks, no prose.
- [x] `scripts/healthcheck.sh` — 62-line production-grade script demonstrating all 6 patterns: `set -euo pipefail`, `readonly`, `log/err/die/usage`, preflight `command -v` loop, `local` vars, `timeout`-bounded ping, HTTP status capture, `getopts`, `main "$@"`.
- [x] `practice/bash-scripting-practice.md` — 20 exercises across 7 sections + 1 capstone, each with ✓ Pass criteria.
- [x] `practice/01-no-set-e.sh` — observe silent failure cascade
- [x] `practice/02-with-set-e.sh` — compare with set -e
- [x] `practice/03-pipefile.sh` — pipefail trap experiment
- [x] `practice/04-if-suppresses-e.sh` — if vs bare command
- [x] `practice/04b-redirect-observe.sh` — fd diagram, 2>&1 order
- [x] `practice/05-capture-output.sh` — if output=$(curl) pattern
- [x] `practice/05b-number-string-compare.sh` — ASCII trap, word splitting
- [x] `practice/06-or-true.sh` — || true annotation exercise
- [x] `practice/07-validation.sh` — 3 validation patterns implemented, 10 test cases passing
- [x] `practice/07b-path-hygiene.sh` — cron PATH simulation
- [x] `practice/08-exit-codes.sh` — exit 1 vs 2 skeleton
- [x] `practice/08-caller.sh` — caller case handler skeleton
- [x] `practice/09-file-tests.sh` — file test observation
- [x] `practice/10-local-leak.sh` — local variable leak observation
- [x] `practice/11-local-exitcode.sh` — local $(cmd) exit code trap observation
- [x] `practice/12-structured.sh` — 6-section script skeleton
- [x] `practice/13-scriptdir.sh` — SCRIPT_DIR vs CWD observation
- [x] `practice/14-deploy-check.sh` — capstone skeleton with checklist

---

## How I Used Claude Code Today

Day 17 was a theory-heavy session building the bash scripting foundation from scratch. Unlike Days 14–16 which were hands-on cluster operations, today was about understanding failure modes before hitting them in production.

The approach was question-by-question: each concept was explained, then demonstrated with a minimal script that fails in an observable way (no `set -e`), then fixed. The `01-no-set-e.sh` vs `02-with-set-e.sh` pair was particularly effective — seeing the same script with and without the flag made the exit code difference concrete rather than theoretical.

Claude Code generated all 18 practice scripts and the memory reference file. The `07-validation.sh` was iteratively refined — an initial draft had the 3 patterns mixed together in the wrong order; it was rewritten so Pattern 1 (`$#`), Pattern 2 (`${:?}`), and Pattern 3 (`usage()`) are clearly separated with section headers. All 10 test cases pass (verified via WSL + PowerShell).

The `scripts/healthcheck.sh` was written twice — first draft was 91 lines (too long), rewritten to 62 lines by merging obvious one-liners and removing redundant blank lines while keeping all 6 patterns demonstrable.

---

## Blockers / Questions for Mentor

- In `set -e` + functions: if a function is called from an `if` condition (`if my_func; then`), `-e` is suppressed for the *entire function body*, not just the call. This means a `curl` failure inside the function won't abort the script. Is the recommended pattern to use `|| return 1` on every risky call inside the function, or to let the function propagate its own exit code and only use `if` at the call site for expected failures?

- For the capstone `14-deploy-check.sh`: dry-run mode can be implemented as `DRY_RUN=true` flag that wraps commands in an `echo`. But if the `if cmd; then` pattern is used for `kubectl cluster-info`, dry-run needs to skip the real call entirely. Is the standard pattern to pass `--dry-run=client` to kubectl, or to `echo` the command and fake the exit code?

---

## Self Score
- Completion: 10/10 — all 10 questions done, all artifacts created, 07-validation.sh fully working
- Understanding: 9/10 — pipefail mechanics, `local` exit code hiding, `2>&1` order are concrete; `set -e` suppression inside nested functions still slightly fuzzy
- Energy: 8/10

---

## One Thing I Learned Today That Surprised Me

`local var=$(cmd)` silently hides the exit code of `cmd`. The `local` builtin always exits 0 (it's just declaring a variable), so `set -e` never fires. This means a script can have `set -euo pipefail` at the top, pass a code review, and still silently swallow failures from subcommand substitutions — purely because they're on the same line as `local`. The fix is two lines, not one. This is exactly the kind of subtle behavior that makes bash dangerous for anything critical: the error-safe pattern looks almost identical to the unsafe one. `shellcheck SC2155` catches this automatically, which is why running shellcheck before commit is non-negotiable.

---

## Tomorrow's Context Block

**Where I am:** Day 17 complete — bash scripting foundation built. All 7 topic areas covered: exit codes, `set -euo pipefail`, strict vs explicit error handling, input validation (3 patterns), stream redirection (fd/2>&1), conditional checks (file/string/number), script structure (local/readonly/main pattern), PATH hygiene. `memory/bash-scripting.md` written as 7-section reference. `scripts/healthcheck.sh` (62 lines, all patterns) and 18 practice scripts created. `07-validation.sh` fully implemented with 10 test cases passing.

**What's in progress / unfinished:** `practice/12-structured.sh` and `practice/14-deploy-check.sh` are skeletons — the capstone exercises remain to be implemented by hand. shellcheck automated validation not yet run on all practice scripts.

**First thing to do next session:** Check Day 18 assignment. Before starting: implement `12-structured.sh` and `14-deploy-check.sh` from the skeletons, run `shellcheck practice/*.sh` to catch any remaining issues. Add `shellcheck` as a git pre-commit hook so it runs automatically.
