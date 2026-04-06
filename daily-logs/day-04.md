# Daily Log — Tin (Trần Trung Tín) — Day 4 — 2026-04-07

## Today's Assignment
- [x] Q1 — SSH orientation: hostname, OS version, current user, sudo, uptime + load
- [x] Q2 — Find log files: find by pattern, grep for errors, tail -f live watch
- [x] Q3 — Read permission string character by character: chmod numeric + symbolic, why not 777
- [x] Q4 — Fix ownership: chown, verify with ls -la, why running as root is refused
- [x] Q5 — systemd crash recovery: status, restart, journalctl, Restart= unit config, service lifecycle
- [x] Q6 — Server performance: top/ps/vmstat columns, identify top CPU process, kill vs kill -9, ss port lookup
- [x] Q7 — Package management: apt two-command sequence, yum/dnf equivalent, verify install, search installed
- [x] Q8 — Write memory/linux-basics.md (5 required sections)
- [ ] Publish IRD-001 to Notion via /write-ird
- [ ] Create first real Linear training issue via /create-linear-issue
- [ ] Open feat/w1-* branch following IRD-001 commit standards

## Linux Environment Used
WSL2 (Ubuntu on Windows 11 Pro) — all commands run in real terminal, real output observed.

## Completed
- [x] Q1: Orientation commands — `hostname -f`, `cat /etc/os-release && uname -r`, `whoami && id && sudo -l`, `uptime`. Understood load average as CPU queue depth divided by core count. `sudo -l` output tells you exact permissions granted, NOPASSWD entries, and whether you can escalate.
- [x] Q2: Log hunting — `find /var -name "*.log" -size +1M 2>/dev/null`, `grep -n -C 5 "ERROR"`, `tail -n 50 -f app.log | grep --line-buffered "ERROR"`. Key insight: `--line-buffered` is mandatory when piping to grep on a live stream — without it output batches and you see nothing until the buffer fills.
- [x] Q3: Permission string decoded position by position — `d|rwx|r-x|r-x` = type|owner|group|other. On directories: `r`=list contents, `w`=create/delete inside, `x`=enter. Numeric: read=4, write=2, execute=1, sum per triplet → 755, 644, 600, 700. Why 777 is wrong: any process on the system gets write — demonstrated with web shell attack chain (world-writable upload dir → PHP shell upload → RCE as www-data).
- [x] Q4: `sudo chown appuser:appuser /var/app/data` — `-R` flag for recursive (use carefully). Verify: `ls -la /var/app/ | grep data`, confirm: `sudo -u appuser touch /var/app/data/testfile`. Root security argument: if app runs as root and is compromised, attacker inherits full OS control — reads /etc/shadow, writes SSH backdoor keys, overwrites system binaries, pivots to other servers. As limited user: attacker is boxed to that user's files only.
- [x] Q5: `systemctl status myapp -l` — decoded every output field (Loaded/Active/Process/exit code). `journalctl -u myapp -n 100 --no-pager`, time-bounded and priority-filtered variants. Unit file `Restart=on-failure` with `RestartSec=5s`, `StartLimitBurst=3` rate limiting. Full systemd lifecycle traced: read unit → evaluate dependencies → set execution context → ExecStartPre → ExecStart → wait for readiness (Type=) → Active → exit → Restart= decision → StartLimitBurst check.
- [x] Q6: `top` header decoded — load average interpretation, %wa iowait (>10% = disk bottleneck), swap usage. `vmstat 2 10` — r (run queue), b (blocked on I/O), si/so (swap in/out), cs (context switches). `ps aux --sort=-%cpu | head -10`. Kill sequence: SIGTERM first (`kill PID`, wait 5s, `ps -p PID`), SIGKILL only if still alive (`kill -9 PID`). SIGTERM is catchable (clean shutdown), SIGKILL is not (kernel terminates instantly, no flush, no cleanup). `sudo ss -tlnp | grep :8080` to find process on a port.
- [x] Q7: `apt update && apt install -y htop` — `apt update` downloads the package index into `/var/lib/apt/lists/`; skipping it causes "Unable to locate package", wrong versions, broken dependencies, or security gap (installs vulnerable version). RHEL: `dnf install -y htop`. Verify: `which htop && htop --version`. `dpkg -l | grep htop` (status `ii`=installed). `rpm -q htop` returns version string or "not installed" — scriptable. `rpm -V nginx` output letter codes: S=size, 5=hash, T=mtime — any output means modified after install (tamper indicator).
- [x] Q8: memory/linux-basics.md written with 5 sections — filesystem hierarchy (6 directories with incident examples), permission model (string parsing, numeric table, 777 attack scenario), user/group management (/etc/passwd and /etc/shadow split explained field by field), process/service management (ps/top/kill/systemctl + full systemd lifecycle), package management (apt/dnf side-by-side table + rpm -V tamper detection).

## Not Completed
| Item | Reason | Time Spent |
|---|---|---|
| Publish IRD-001 to Notion | Discovery chain + Explore Further filled session | 0hr |
| Create first real Linear issue | Carried over again — Day 5 first priority | 0hr |
| Open feat/w1-* branch | Carried over | 0hr |

## Extra Things Explored (Explore Further)
- **`/proc/[pid]` live diagnostics** — zero-tool process inspection in production:
  - `/proc/PID/stat` fields 14+15 (utime+stime) → CPU ticks consumed, convert via `getconf CLK_TCK`
  - `/proc/PID/schedstat` field 2 → nanoseconds waiting in run queue (scheduler starvation indicator)
  - `/proc/PID/status` VmRSS = actual RAM in use (VmSize is misleading — inflated by mmap), VmSwap > 0 means process is paged out
  - `/proc/PID/smaps` Private_Dirty → unshared RAM that can't be freed without swap — the real memory cost
  - `/proc/PID/fd/` symlinks → every open file, socket, pipe visible by FD number; count vs `/proc/PID/limits` Max open files to catch "too many open files" before it hits
  - `/proc/PID/maps` → loaded shared libraries, memory-mapped files — grep `.so` to list all linked libs

## Artifacts Built Today
- [x] `memory/linux-basics.md` — new file: filesystem hierarchy, permission model, user/group mgmt, process/service mgmt, package management — written for agent consumption with incident-context examples and DevOps reasoning throughout

## How I Used Claude Code Today
Worked through the Day 4 discovery chain as a single continuous production incident — SSH into unknown server → find logs → fix permissions → fix ownership → recover crashed service → diagnose slow server → install monitoring tool → write memory file. Claude framed every answer around that incident thread, which made each command feel purposeful rather than academic. The Explore Further question on `/proc` was the most technically dense — no tools required, just file reads, but gives deeper visibility than `top` or `ps` for diagnosing a specific PID in production.

## Blockers / Questions for Mentor
- IRD-001 is now 4 days overdue. Should I spend Day 5 morning on carry-over before starting new content, or should I treat the carry-over as a parallel track and not block Day 5 topic start?
- The `/proc` exploration showed that `VmRSS` can look fine while `Private_Dirty` is very high — is this a common gotcha in container memory limit tuning (since cgroup limits are based on RSS)?

## Self Score
- Completion: 8/10 (all 8 Qs done + Explore Further, carry-over tasks still pending)
- Understanding: 9/10
- Energy: 8/10

## One Thing I Learned Today That Surprised Me

Running an application as root is not just "bad practice" — it completely eliminates containment. With a limited user, a compromised process is a contained incident: app data is at risk, the OS is not. With root, the OS, all other services, all credentials on disk, and every server reachable via SSH keys are at risk simultaneously. The concrete attack chain makes this concrete: compromised root process → read `/etc/shadow` → crack all passwords offline → read `/root/.ssh/id_rsa` → SSH into every other server that trusts this key → all before the first alert fires. Least privilege is not a checkbox — it is the boundary that defines blast radius.

---

## Tomorrow's Context Block

**Where I am:** End of Day 4, Week 1 — all 8 Linux Basics discovery questions completed plus Explore Further (/proc filesystem). Memory file created: memory/linux-basics.md with 5 sections covering filesystem hierarchy, permissions, user/group management, process/service management, and package management. Carry-over still open: IRD-001 unpublished, no Linear issue created, no feat/w1-* branch opened.

**What to do tomorrow (Day 5):** Clear carry-over first — publish IRD-001 via /write-ird, create first Linear training issue via /create-linear-issue, open feat/w1-* branch. Then start Day 5 topic: Virtualization + Cloud Basics.

**Open question:** Is the `/proc` Private_Dirty metric the right number to watch when tuning Kubernetes container memory limits, since cgroup enforcement is based on working set rather than VmSize?
