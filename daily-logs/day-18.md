# Daily Log — Tin (Trần Trung Tín) — Day 18 — 07 May 2026

## Today's Assignment (Day 18 — Bash Automation: From Scripts to Production-Grade Deploy Pipelines)
- [x] Q1 — Deploy chain: `git pull --ff-only` → `docker build` → `docker push` → `kubectl rollout` with exit code guards at each phase
- [x] Q2 — Two failure modes a manual process misses: diverged branch (caught by `--ff-only`) and silent push failure (caught by explicit exit code check)
- [x] Q3 — Idempotency pattern: `.last-deploy` state file, write AFTER success, `|| echo ""` first-run case
- [x] Q4 — AWS preflight checks: EC2 instance state via `aws ec2 describe-instances`, health endpoint via `curl --max-time 5 || echo "000"`, `aws ec2 wait` for state-change
- [x] Q5 — Structured logging: `[ts][phase] START/OK/FAIL msg` pattern, two-layer helpers (`start/ok/fail` for phases, `log/die` for setup), CI grep-ability
- [x] Q6 — Log monitoring with deduplication: `tail -F` vs `tail -f`, `grep --line-buffered`, sha256sum hash key, awk pruning, `send_alert` stub
- [x] Q7 — Cron crash course: crontab syntax, why cron fails (no PATH, no profile), fixes (explicit PATH, output redirect, `env -i` test), `flock` for overlapping runs
- [x] Q8 — Dry-run pattern: `run()` wrapper, mutating vs read-only distinction, redirect exception, `--dry-run` pre-processing before `getopts`
- [x] Q9 — Artifacts: `scripts/deploy.sh`, `scripts/deploy-minikube.sh`, `scripts/monitor-logs.sh`, `scripts/cron-safe-template.sh`, `skills/bash-automation.md`

## Environment
Windows 11 Pro, Claude Code CLI inside VSCode. Scripts run under WSL (Ubuntu) / bash syntax-checked with `bash -n`. No cloud resources used — local scripting session building on Day 17 bash foundation. All scripts passed `bash -n` syntax check.

---

## Completed

- [x] **Q1 — Deploy chain: 4-phase script with exit code guards**

  Built `scripts/deploy.sh` — chains 4 phases, each with `start/ok/fail` structured logging:

  ```
  phase_git()    → git pull --ff-only  → COMMIT=$(git rev-parse --short HEAD)
  phase_build()  → docker build --platform=linux/amd64 -t $image .
  phase_push()   → docker push $image  (explicit exit code capture)
  phase_deploy() → kubectl set image + kubectl rollout status --timeout=120s
  ```

  Tag pattern: `registry/myapp:$COMMIT` — every image traceable to a git state. Never `:latest` in production because `:latest` has no information about which code it contains.

  `kubectl rollout status` is blocking — script does not exit until pods are Ready or timeout. Without it, the script would report success before a single new pod starts.

  Also built `scripts/deploy-minikube.sh` — same 4-phase structure with three differences:
  - No `--platform=linux/amd64` (minikube uses host arch)
  - Phase 3: `minikube image load` instead of `docker push` (no registry needed)
  - Preflight: `minikube status` check instead of ECR auth check
  - Requirement: deployment needs `imagePullPolicy: IfNotPresent`

- [x] **Q2 — Two failure modes a manual process misses**

  **Failure mode A — diverged branch:**
  `git pull --ff-only` aborts if local and remote have diverged instead of silently creating a merge commit. Plain `git pull` would produce a merge SHA — `$COMMIT` would point to merged code, not a clean tree state, and the image tag would be non-reproducible.

  **Failure mode B — silent push failure:**
  An expired ECR token causes `docker push` to exit 1 with no stdout output. Without explicit exit code capture, `set -e` alone isn't enough because we need to emit a specific diagnosis message. Pattern used:
  ```bash
  local push_exit=0
  docker push "$image" || push_exit=$?
  (( push_exit == 0 )) || fail push "docker push exited $push_exit — refresh ECR token..."
  ```
  Without this guard: script continues, `kubectl` deploys the previous stale image, reports "success".

- [x] **Q3 — Idempotency: `.last-deploy` state file**

  Three-part pattern:
  ```bash
  # 1. Read previous commit — || echo "" handles first run (file doesn't exist yet)
  last=$(cat .last-deploy 2>/dev/null || echo "")

  # 2. Skip if unchanged — exit 0 because skipping is success, not failure
  [[ "$COMMIT" == "$last" ]] && { log "SKIP no changes since $COMMIT"; exit 0; }

  # 3. Write AFTER deploy succeeds — writing before means a failed deploy looks done
  echo "$COMMIT" > .last-deploy
  ```

  Why write AFTER: if `phase_deploy` fails, `set -e` stops the script. The file never gets written. Next run retries correctly. If written before, the failed deploy would be marked as "already deployed" and the next run would skip it silently.

  Edge: if someone `kubectl set image` manually, `.last-deploy` file lies. Real production solution: store deployed commit as K8s annotation (`kubectl annotate deployment/myapp deployed-commit="$COMMIT" --overwrite`) or a git tag. File is sufficient for training context.

  `.last-deploy` is auto-gitignored by the existing `.*` pattern in `.gitignore`.

- [x] **Q4 — AWS preflight checks**

  Built as `preflight()` function called at the top of `main()` — runs before `phase_git`, so a bad EC2 state is caught before wasting time on build + push.

  **EC2 instance state check:**
  ```bash
  state=$(aws ec2 describe-instances \
    --instance-ids "$instance_id" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text)
  [[ "$state" == "running" ]] || fail preflight "instance is '$state'"
  ```
  Read-only → does NOT go through `run()` — output needed for comparison.

  **Health endpoint check:**
  ```bash
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://$host/health" \
    || echo "000")
  [[ "$status" == "200" ]] || fail preflight "health returned $status"
  ```
  `|| echo "000"`: if curl fails entirely (timeout, DNS failure), still get a string to compare. Without it, `set -e` crashes the script before `fail()` can emit a useful message. `"000"` is never a valid HTTP status code, so the `!= "200"` check always triggers correctly.

  **`aws ec2 wait`:** `aws ec2 wait instance-running --instance-ids $INSTANCE_ID` blocks until instance is running (max ~10 minutes). Shown in `die()` message as a manual fix command — not called automatically inside the script. Auto-waiting in a deploy script is dangerous: a stuck wait silently holds up the entire pipeline.

  Both checks are optional — activated only when `-i` (instance ID) or `-H` (host) flags are passed.

- [x] **Q5 — Structured logging: two-layer helper pattern**

  Old helpers: `log/err/die` — flat, no phase information.

  New helpers:
  ```bash
  _ts()   { date -u +%Y-%m-%dT%H:%M:%SZ; }
  start() { echo "[$(_ts)] [$1] START $2"; }      # phase start
  ok()    { echo "[$(_ts)] [$1] OK $2"; }          # phase success
  fail()  { echo "[$(_ts)] [$1] FAIL $2" >&2; exit 1; }  # phase failure
  log()   { echo "[$(_ts)] [deploy] INFO $*"; }   # non-phase messages
  die()   { echo "[$(_ts)] [deploy] FAIL $*" >&2; exit 1; }
  ```

  Two-layer design: `start/ok/fail` tag by phase (`[git]`, `[build]`, `[push]`, `[deploy]`, `[preflight]`), `log/die` tag as `[deploy]` for setup, idempotency, and state messages.

  CI grep patterns enabled:
  ```bash
  grep '\[git\] FAIL'    deploy.log   # → deploys that failed at diverged branch
  grep '\[push\] FAIL'   deploy.log   # → ECR token expiry incidents
  grep '\[deploy\] FAIL' deploy.log   # → rollout crash events
  ```

  JSON logging is the production upgrade:
  ```bash
  ok() { printf '{"ts":"%s","phase":"%s","status":"OK","msg":"%s"}\n' "$(_ts)" "$1" "$2"; }
  ```
  Enables `SELECT phase, msg WHERE status = "FAIL"` in Datadog/Loki/CloudWatch without regex. Text format sufficient for today; JSON when log aggregator is in place.

- [x] **Q6 — Log monitoring with deduplication**

  Built `scripts/monitor-logs.sh`:

  ```bash
  tail -F "$logfile" \
    | grep --line-buffered -E '\[ERROR\]|\bERROR\b' \
    | while read -r line; do
        key=$(echo "$line" | sha256sum | cut -c1-12)
        grep -q "^$key " "$DEDUP_FILE" 2>/dev/null && continue
        echo "$key $(date +%s)" >> "$DEDUP_FILE"
        send_alert "$line"
      done
  ```

  **`tail -F` (uppercase F):** follows file by name, not inode. Reconnects after logrotate creates a new file. `tail -f` (lowercase) follows inode — silently stops receiving logs after rotation. Monitoring appears to work but is actually deaf.

  **`grep --line-buffered`:** flushes each line immediately instead of buffering 4KB blocks. Without it, alerts arrive in batches, not real-time. An error at 14:30:00 might not fire until 14:30:30.

  **Dedup flow:**
  ```
  line → sha256 → 12-char key
       → key in DEDUP_FILE? → YES: suppress (continue)
                            → NO:  write "key timestamp" → send_alert
  ```
  Write BEFORE alert: if webhook fails, entry is still recorded. Next time the same error fires, it's correctly suppressed instead of alerting again.

  **Dedup TTL pruning (at startup):**
  ```bash
  awk -v cutoff=$(($(date +%s) - DEDUP_TTL)) '$2 > cutoff' "$DEDUP_FILE" \
    > "$DEDUP_FILE.tmp" && mv "$DEDUP_FILE.tmp" "$DEDUP_FILE"
  ```
  Write to `.tmp` then `mv` — atomic swap prevents truncating the file while it's being read by another process.

  **Why dedup is non-negotiable:** without it, an error in a tight loop fires 10,000 alerts per minute. Engineers turn off alerts. Production goes down silently.

- [x] **Q7 — Cron crash course + `cron-safe-template.sh`**

  Built `scripts/cron-safe-template.sh` as reusable template for any cron job.

  **Crontab syntax:** `MIN HOUR DOM MON DOW command`
  ```cron
  */5 * * * *   /script.sh    # every 5 minutes
  0 2 * * *     /backup.sh    # 2am daily
  0 9 * * 1     /report.sh    # 9am every Monday
  ```

  **Why cron scripts fail:**

  | Problem | Symptom | Fix |
  |---------|---------|-----|
  | Minimal PATH | `aws: command not found` | `export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"` |
  | No profile loaded | `AWS credentials not found` | `export AWS_PROFILE="prod"` in script header |
  | Output dropped | Cron runs but nothing visible | `>> /var/log/script.log 2>&1` in crontab |
  | Overlapping runs | Two instances conflict on same resource | `flock -n 9 || exit 0` |

  **`flock` lock pattern:**
  ```bash
  exec 9>"$LOCK_FILE"
  flock -n 9 || { log "SKIP already running"; exit 0; }
  # fd 9 auto-released on script exit
  ```
  If cron interval is 5 min but script takes 7 min, second run exits immediately instead of running in parallel.

  **Test before scheduling:**
  ```bash
  env -i PATH=/usr/bin:/bin HOME=$HOME /path/to/script.sh
  ```
  If it passes here, it passes in cron.

- [x] **Q8 — Dry-run pattern**

  Added `--dry-run` flag to both `deploy.sh` and `cron-safe-template.sh`.

  **`run()` wrapper:**
  ```bash
  run() {
    [[ $DRY_RUN -eq 1 ]] && echo "[$(_ts)] [deploy] DRY-RUN: $*" || "$@"
  }
  ```
  `"$@"` executes with full argument quoting — no `eval`, no string splitting, no injection risk.

  **Three categories:**

  | Category | Pattern | Reason |
  |----------|---------|--------|
  | Mutating commands | `run docker build ...` | Has side effects |
  | Read-only commands | `COMMIT=$(git rev-parse ...)` | Output needed for downstream logic |
  | Redirects | `if [[ $DRY_RUN -eq 1 ]]; then log "DRY-RUN: echo ..."; else echo "$COMMIT" > .last-deploy; fi` | `>` executes before `run()` is called — shell truncates the file before function runs |

  **`--dry-run` pre-processing before `getopts`:**
  `getopts` only handles short flags (`-r`, `-n`). Long flags (`--dry-run`) need manual pre-processing:
  ```bash
  filtered=()
  for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=1 || filtered+=("$arg")
  done
  (( ${#filtered[@]} > 0 )) && set -- "${filtered[@]}" || set --
  ```
  Rebuilds `$@` without `--dry-run` so `getopts` processes the remaining short flags normally.

  **Validation rule:** dry-run output must exactly match real execution order. Divergence (dry-run skips a step, or has `if DRY_RUN` branches) makes the review output misleading — worse than no dry-run.

- [x] **Q9 — `skills/bash-automation.md`**

  Created `skills/bash-automation.md` — a skill file (not a memory reference). Structure:
  - Trigger condition: 2+ manual runs, cron/CI, failure costs money or sleep
  - Six design questions to answer before writing line one
  - Full copy-paste script skeleton with all Day 17–18 patterns
  - Four canonical patterns (deploy chain, AWS preflight, log monitor, cron-safe)
  - Five pitfalls from today (not generic)
  - Dry-run rule: mutating vs read-only table

---

## Not Completed
| Item | Reason |
|------|--------|
| `practice/12-structured.sh` full implementation | Carry-over from Day 17 — deferred again |
| `practice/14-deploy-check.sh` full implementation | Carry-over from Day 17 — deferred again |
| `shellcheck` run on all Day 18 scripts | `bash -n` confirms syntax; shellcheck deferred |

---

## Extra Things Explored

- **`if grep -q` safe with `set -e`:** Commands inside `if` condition suppress `-e`. `grep -q` returning exit 1 (no match) enters the `else` branch — does not crash the script. This is why `if grep -q "^$key " "$DEDUP_FILE"` is the correct pattern, not `grep -q ... && continue`.

- **`|| echo ""` vs `[[ -f file ]]`:** Both handle "file might not exist". `last=$(cat .last-deploy 2>/dev/null || echo "")` is one line vs a separate `if [[ -f .last-deploy ]]` branch. Cleaner for idempotency checks where the file's non-existence is the normal first-run case.

- **Why `tail -F` for log rotation:** Docker log drivers, logrotate, and systemd journal all rotate files. `-f` follows the inode that gets unlinked — script keeps reading the old (now empty or deleted) file. `-F` notices the file was replaced and reopens the new one. Silent monitoring failure is the worst kind: on-call thinks monitoring is active, it's actually blind.

- **Dedup hash length:** 12 hex characters from sha256 = 48 bits of collision space (~1 in 10^14). For log dedup with thousands of unique error messages, collision probability is negligible. Using full 64-char sha256 hash in the dedup file wastes space and slows grep.

---

## Artifacts Built Today

- [x] `scripts/deploy.sh` — 141-line EKS deploy script: 4 phases, structured logging, idempotency, AWS preflight, dry-run, `--ff-only`, explicit push exit code guard, `rollout status` blocking
- [x] `scripts/deploy-minikube.sh` — minikube variant: `minikube image load` instead of push, no `--platform`, `minikube status` preflight
- [x] `scripts/monitor-logs.sh` — log monitor: `tail -F`, `grep --line-buffered`, sha256 dedup, awk TTL pruning, `send_alert` stub (file today, webhook pattern commented)
- [x] `scripts/cron-safe-template.sh` — cron-safe template: explicit PATH, env var section, `flock` lock, `run()` dry-run wrapper, `--dry-run` parsing
- [x] `skills/bash-automation.md` — bash automation skill: trigger conditions, 6 design questions, full skeleton, 4 canonical patterns, 5 pitfalls, dry-run rule

---

## How I Used Claude Code Today

Day 18 applied the bash foundation from Day 17 to a complete, real-world automation problem: a production-grade deploy pipeline. Each concept was introduced as a requirement ("what would break without this?"), then implemented.

The deploy script was built incrementally across the session — starting with the 4-phase chain, then layering in idempotency, then AWS preflight, then structured logging, then dry-run. Each layer was added to the same file, letting the evolution of `deploy.sh` demonstrate how a script grows from "works on my machine" to "safe to run in cron at 3am."

The most effective teaching moment: showing the two failure modes (`--ff-only` and push exit code) with concrete consequences — not "this might fail" but "without this, kubectl deploys the stale image and reports success." Making failure modes concrete rather than theoretical was the consistent pattern across Q1–Q8.

Claude Code generated all 5 scripts and the skill file, refined `deploy.sh` through 6+ iterations (idempotency → preflight → structured logging → dry-run), and syntax-checked each artifact with `bash -n`.

---

## Blockers / Questions for Mentor

- `scripts/deploy.sh` and `scripts/deploy-minikube.sh` are separate files, but they share ~80% of the code (helpers, phase_git, phase_build). The right architecture would be a shared `lib/deploy-common.sh` sourced by both. Is the standard approach to `source` a lib file from the same directory using `SCRIPT_DIR`, or is a single script with a `--target eks|minikube` flag preferred?

- The `preflight()` function checks EC2 state and health endpoint. But in a true CI/CD pipeline (GitHub Actions → EKS), EC2 instance checks are not relevant — the cluster handles its own node pool. Is there a standard "EKS-specific preflight" (e.g., check node count, check namespace exists, check pod disruption budget) that should replace the EC2 check in that context?

---

## Self Score
- Completion: 10/10 — all 9 questions done, all 5 artifacts created, `bash -n` clean on all scripts
- Understanding: 9/10 — `tail -F` rotation behavior, `--line-buffered` mechanics, and dry-run redirect exception are concrete; `flock` fd mechanics slightly fuzzy
- Energy: 8/10

---

## One Thing I Learned Today That Surprised Me

Redirects (`>`) execute before the function they appear in is called. This means `run echo "$COMMIT" > .last-deploy` would truncate `.last-deploy` immediately — even in dry-run mode — because the shell processes the redirect at parse time, not at function call time. The `run()` function never sees the redirect. This is why the `.last-deploy` write needs an explicit `if [[ $DRY_RUN -eq 1 ]]` branch instead of going through `run()`. The rest of the script wraps every mutating command in `run()`, but this one case looks identical to the others and silently bypasses the abstraction. It's the kind of bash behavior that only surfaces when you test the dry-run path — which is exactly the argument for testing dry-run on every deploy before running for real.

---

## Tomorrow's Context Block

**Where I am:** Day 18 complete — bash automation pipeline built end-to-end. Five scripts created: `deploy.sh` (EKS, 141 lines, idempotent + preflight + structured logging + dry-run), `deploy-minikube.sh` (minikube variant), `monitor-logs.sh` (real-time ERROR monitor with sha256 dedup), `cron-safe-template.sh` (reusable cron pattern), `skills/bash-automation.md` (skill file with 6 design questions + 4 canonical patterns). All scripts pass `bash -n`. Day 17 carry-overs (`practice/12` and `practice/14` full implementation) still pending.

**What's in progress / unfinished:** `practice/12-structured.sh` and `practice/14-deploy-check.sh` skeletons from Day 17 remain unimplemented. `shellcheck` not yet run on Day 18 scripts.

**First thing to do next session:** Check Day 19 assignment. Before starting: run `shellcheck scripts/deploy.sh scripts/deploy-minikube.sh scripts/monitor-logs.sh scripts/cron-safe-template.sh` — fix any warnings. Implement Day 17 carry-overs (`practice/12` and `practice/14`). Consider extracting shared deploy logic into `scripts/lib/deploy-common.sh` if Day 19 adds another deploy target.
