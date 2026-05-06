# Skill Name: Bash Automation

**What It Does:** Converts any manual, repeated, or failure-sensitive task into a production-grade bash script with error handling, preflight checks, structured logging, dry-run, and idempotency.

---

## When To Use

- Task done manually **2+ times** → automate it
- Task runs in **cron, CI, or scheduled job**
- Task failure **costs money or sleep** (deploy, backup, sync)
- Task has **multiple steps** where a mid-failure leaves broken state

---

## Input Required

- [ ] What the script does (one sentence)
- [ ] Target environment: local / EC2 / EKS / cron
- [ ] Inputs the script takes (flags, env vars)
- [ ] What tools are required (`aws`, `kubectl`, `docker`, etc.)
- [ ] Whether it runs unattended (cron → needs PATH + output redirect)

---

## The Prompt

```
Act as a Senior DevOps Engineer. Write a bash script that [TASK_DESCRIPTION].

Answer the six design questions first, then write the script:
Q1. What does the script do, in one sentence?
Q2. What inputs does it take? Which are required vs optional?
Q3. What can go wrong at each step?
Q4. What should it check BEFORE making changes?
Q5. How does it report status?
Q6. Is it idempotent — safe to run twice?

Requirements:
- Header: #!/usr/bin/env bash + set -euo pipefail
- Helpers: _ts, log, die, start/ok/fail (structured), run (dry-run)
- preflight() checks: [REQUIRED_TOOLS], [AWS_STATE or HEALTH_ENDPOINT]
- Phase functions: one function per concern
- --dry-run flag: mutating commands via run(), read-only commands bare
- Idempotency: [STATE_FILE or ANNOTATION] to skip unchanged runs
- Cron-safe if needed: explicit PATH, output redirect in crontab comment
- Structured log format: [timestamp] [phase] STATUS message

Target: [local | EC2 | EKS | cron]
Tools required: [LIST]
Inputs: [FLAGS AND ENV VARS]
```

---

## Six Design Questions

Answer these BEFORE writing line one:

**Q1 — What does it do?**
- One sentence. If you need two sentences, the script does too much — split it.

**Q2 — Inputs?**
- Required flags → missing = `usage()` + exit 2
- Optional flags → missing = sensible default
- Never hardcode: registry, namespace, instance ID, host

**Q3 — What can go wrong?**
- Network: timeout, DNS failure, unreachable host
- Auth: expired token (ECR), missing AWS credentials, wrong kubectl context
- State: branch diverged, image already exists, deployment not found
- Tools: `jq` missing in cron environment

**Q4 — Preflight checks?**
- Tool presence: `command -v <tool> || die`
- AWS instance state: `aws ec2 describe-instances` → must be `running`
- Health endpoint: `curl --max-time 5` → must return `200`
- kubectl context: `kubectl config current-context` → must exist
- Run preflight BEFORE build/push — fail fast, not after wasted work

**Q5 — Status reporting?**
- Every phase: `start phase msg` → `ok phase msg` or `fail phase msg`
- `fail` writes to stderr, exits 1
- `ok` writes to stdout
- CI grep pattern: `\[phase\] FAIL` to find broken phase across 1000 runs

**Q6 — Idempotent?**
- State file: `echo "$COMMIT" > .last-deploy` (write AFTER success, not before)
- Or K8s annotation: `kubectl annotate deployment/myapp deployed-commit="$COMMIT"`
- Skip condition: `[[ "$COMMIT" == "$last" ]] && exit 0`

---

## Standard Script Skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail

# --- globals -----------------------------------------------------------------
COMMIT=""
DRY_RUN=0
# export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"  # uncomment for cron

# --- helpers -----------------------------------------------------------------
_ts()   { date -u +%Y-%m-%dT%H:%M:%SZ; }
start() { echo "[$(_ts)] [$1] START $2"; }
ok()    { echo "[$(_ts)] [$1] OK $2"; }
fail()  { echo "[$(_ts)] [$1] FAIL $2" >&2; exit 1; }
log()   { echo "[$(_ts)] [script] INFO $*"; }
die()   { echo "[$(_ts)] [script] FAIL $*" >&2; exit 1; }
run()   {
  [[ $DRY_RUN -eq 1 ]] && echo "[$(_ts)] [script] DRY-RUN: $*" || "$@"
}

usage() {
  cat >&2 <<EOF
Usage: $0 -r <required> [--dry-run] [-o <optional>]
  -r   Required input
  -o   Optional input   default: value
  --dry-run   Print commands, do not execute
EOF
  exit 2
}

# --- preflight ---------------------------------------------------------------
preflight() {
  local missing=()
  for cmd in git docker kubectl aws; do
    command -v "$cmd" >/dev/null || missing+=("$cmd")
  done
  (( ${#missing[@]} == 0 )) || die "Missing tools: ${missing[*]}"

  # AWS instance check (if applicable)
  # local state
  # state=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  #   --query 'Reservations[0].Instances[0].State.Name' --output text)
  # [[ "$state" == "running" ]] || fail preflight "instance is $state"

  # Health endpoint check (if applicable)
  # local status
  # status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://$HOST/health" || echo "000")
  # [[ "$status" == "200" ]] || fail preflight "health returned $status"
}

# --- phases ------------------------------------------------------------------
phase_git() {
  start git "pulling latest"
  run git pull --ff-only \
    || fail git "branch diverged — fix: git rebase origin/$(git branch --show-current)"
  COMMIT=$(git rev-parse --short HEAD)   # read-only: no run()
  ok git "at $COMMIT"
}

phase_build() {
  local image=$1
  start build "$image"
  run docker build --platform=linux/amd64 -t "$image" . || fail build "exited $?"
  ok build "$image"
}

phase_deploy() {
  local image=$1 deployment=$2 namespace=$3
  start deploy "$deployment → $image"
  run kubectl set image "deployment/$deployment" "$deployment=$image" -n "$namespace" \
    || fail deploy "kubectl set image failed"
  run kubectl rollout status "deployment/$deployment" -n "$namespace" --timeout=120s \
    || fail deploy "rollout timed out"
  ok deploy "rollout complete"
}

# --- main --------------------------------------------------------------------
main() {
  local required="" optional="default"

  # Pre-process long flags (getopts doesn't support --)
  local filtered=()
  for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=1 || filtered+=("$arg")
  done
  (( ${#filtered[@]} > 0 )) && set -- "${filtered[@]}" || set --

  while getopts "r:o:h" opt; do
    case $opt in
      r) required=$OPTARG ;;
      o) optional=$OPTARG ;;
      *) usage ;;
    esac
  done

  [[ -n "$required" ]] || usage
  [[ $DRY_RUN -eq 1 ]] && log "DRY-RUN mode"

  preflight

  # Idempotency check
  local last
  last=$(cat .last-deploy 2>/dev/null || echo "")
  phase_git
  [[ "$COMMIT" == "$last" ]] && { log "SKIP no changes since $COMMIT"; exit 0; }

  phase_build  "${required}/myapp:${COMMIT}"
  phase_deploy "${required}/myapp:${COMMIT}" "myapp" "default"

  # Write state AFTER success — writing before means a failed deploy looks done
  if [[ $DRY_RUN -eq 1 ]]; then
    log "DRY-RUN: echo $COMMIT > .last-deploy"
  else
    echo "$COMMIT" > .last-deploy
  fi

  log "DONE"
}

main "$@"
```

---

## Four Canonical Patterns

**1 — Deploy chain (git → build → push → deploy)**
- `scripts/deploy.sh` / `scripts/deploy-minikube.sh` / `scripts/deploy-eks.sh`
- Idempotency via `.last-deploy`; push exit code caught explicitly; rollout status blocks

**2 — AWS preflight check**
```bash
state=$(aws ec2 describe-instances --instance-ids "$ID" \
  --query 'Reservations[0].Instances[0].State.Name' --output text)
[[ "$state" == "running" ]] || fail preflight "instance is $state"
```
- Read-only → no `run()`; run before build, not after

**3 — Log monitor with dedup**
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
- `tail -F` (uppercase): follows file name, survives rotation
- `--line-buffered`: flushes each line immediately, not in 4KB blocks
- Dedup write BEFORE alert, not after

**4 — Cron-safe scheduling**
```bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
# Crontab entry:
# */5 * * * * /path/to/script.sh >> /var/log/script.log 2>&1
```
- Test with: `env -i PATH=/usr/bin:/bin HOME=$HOME /path/to/script.sh`
- Lock against overlapping runs: `flock -n 9 || exit 0`

---

## Five Pitfalls + Fixes

**1 — `git pull` silently merges diverged branch**
- Symptom: `$COMMIT` points to a merge SHA, image tag is non-reproducible
- Fix: `git pull --ff-only` → aborts instead of merging

**2 — `docker push` fails silently (expired ECR token)**
- Symptom: script exits 0, kubectl deploys old image, looks like success
- Fix: `docker push "$image" || push_exit=$?` + explicit `(( push_exit == 0 )) || fail`

**3 — `grep` in pipe buffers output (alerts arrive in batches)**
- Symptom: real-time monitor sends alert 30s after error appears
- Fix: `grep --line-buffered`

**4 — Cron script works in terminal, fails in cron**
- Symptom: `aws: command not found` or `jq: command not found` only in cron
- Fix: `export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"` at top of script

**5 — State file written before deploy completes**
- Symptom: deploy fails mid-way, next run skips it ("already deployed")
- Fix: write `.last-deploy` only after `phase_deploy` returns successfully

---

## Dry-Run Rule

**Mutating commands → always through `run()`:**
```bash
run git pull --ff-only
run docker build ...
run docker push ...
run kubectl set image ...
run kubectl rollout status ...
```

**Read-only commands → always bare (output needed for logic):**
```bash
COMMIT=$(git rev-parse --short HEAD)
state=$(aws ec2 describe-instances ...)
status=$(curl -s ... || echo "000")
last=$(cat .last-deploy 2>/dev/null || echo "")
```

**Redirects → check `$DRY_RUN` directly (`run()` can't wrap `>`):**
```bash
if [[ $DRY_RUN -eq 1 ]]; then
  log "DRY-RUN: echo $COMMIT > .last-deploy"
else
  echo "$COMMIT" > .last-deploy
fi
```

**Validation:** dry-run output must exactly match real execution order. Any divergence means the dry-run is misleading.

---

## Example Usage

**Inputs provided:**
- Task: deploy containerized app to EKS on every git push
- Tools: `git`, `docker`, `kubectl`, `aws`
- Registry: `123456789.dkr.ecr.us-east-1.amazonaws.com`
- Environment: EKS, runs in CI

**What to say:**
```
Run the bash-automation skill.
Task: deploy containerized app to EKS after git pull.
Tools required: git, docker, kubectl, aws.
Inputs: -r <registry> --dry-run [-n namespace] [-d deployment]
Preflight: kubectl context check + ECR login check.
Idempotency: .last-deploy state file.
Target: EKS.
```

---

## Notes / Variations

- **Minikube variant:** remove `--platform=linux/amd64`, replace push with `minikube image load`, add `minikube status` to preflight
- **Compose variant:** replace `phase_deploy` with `docker-compose up -d --no-build`
- **Cron variant:** add `export PATH=...`, `flock` lock, crontab redirect comment
- **No remote state:** `.last-deploy` can lie if someone deploys manually → production fix: read deployed commit from K8s annotation instead
