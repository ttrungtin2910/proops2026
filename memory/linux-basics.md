# Linux Basics Reference for DevOps Agents

---

## 1. Filesystem Hierarchy

The Linux filesystem is a single tree rooted at `/`. Every directory has a defined purpose. During an incident, knowing where to look immediately is the difference between a 2-minute diagnosis and a 20-minute one.

### `/etc` — System-wide configuration files

Contains plain-text configuration for the OS and every installed service. Files here are read by daemons at startup or reload. Changes take effect on restart or `reload`; nothing here is auto-applied.

```
/etc/nginx/nginx.conf          # web server config
/etc/systemd/system/myapp.service  # service unit definition
/etc/hosts                     # local DNS overrides
/etc/environment               # system-wide environment variables
/etc/cron.d/                   # scheduled jobs
/etc/apt/sources.list          # Debian package repo list
/etc/yum.repos.d/              # RHEL repo definitions
```

**During an incident:** A service misbehaves after a deploy. Check `/etc/<service>/` for config that may have been modified. Compare with version control. Run `stat /etc/nginx/nginx.conf` to see when it was last changed.

### `/var` — Variable runtime data (logs, databases, spools, caches)

Data that changes while the system runs. Everything a running service writes to disk lands here. Grows over time — disk-full incidents almost always trace to `/var`.

```
/var/log/                      # all system and application logs
/var/log/syslog                # general system log (Debian)
/var/log/messages              # general system log (RHEL)
/var/log/nginx/access.log      # web server access log
/var/lib/mysql/                # MySQL data files
/var/lib/docker/               # Docker images, containers, volumes
/var/spool/cron/               # pending cron jobs
/var/run/                      # PID files for running services
```

**During an incident:** Service is down with a write error. Check `df -h /var` for disk space. Check `/var/log/<service>/` for the crash reason. Check `/var/run/<service>.pid` to see if a stale PID file is blocking restart.

### `/tmp` — Temporary files, cleared on reboot

World-writable scratch space. Any process can write here. Files survive until reboot (or `systemd-tmpfiles` cleanup, typically after 10 days on modern systems).

```
/tmp/myapp-upload-xyz123       # in-progress file upload staging
/tmp/.X11-unix/                # X display sockets
```

**During an incident:** App fails processing uploads. Check `/tmp` for incomplete staged files consuming disk space. Also: if you see unexpected executables in `/tmp` (e.g., `/tmp/x`, `/tmp/rev`), that is a red flag for a compromise — malware frequently lands in `/tmp` because it's always writable.

```bash
ls -lah /tmp/        # look for unexpected large files or executables
df -h /tmp           # check if it's on a separate tmpfs and full
```

### `/proc` — Virtual filesystem exposing kernel and process state

Not a real disk directory. The kernel generates its contents on-the-fly. Every running process has a subdirectory at `/proc/<PID>/`. Reading these files reads live kernel data.

```
/proc/cpuinfo          # CPU model, core count, flags
/proc/meminfo          # memory stats (used by free, top)
/proc/loadavg          # live load averages
/proc/net/tcp          # raw TCP socket table
/proc/<PID>/cmdline    # exact command line of a running process
/proc/<PID>/environ    # environment variables of a running process
/proc/<PID>/fd/        # file descriptors open by the process
/proc/<PID>/status     # memory, UID, state summary
```

**During an incident:** You have a PID from `ps` or `top` but don't know what the process is doing.

```bash
cat /proc/18234/cmdline | tr '\0' ' '   # full command with args
ls -la /proc/18234/fd/                  # what files/sockets it has open
cat /proc/18234/status | grep -E "Vm|State|Pid"  # memory and state
```

### `/home` — User home directories

Each human user has `/home/<username>/`. Contains personal files, shell config (`.bashrc`, `.bash_profile`), SSH keys (`~/.ssh/`), and application credentials.

```
/home/deploy/.ssh/authorized_keys    # SSH keys allowed to log in as deploy
/home/appuser/.bashrc                # shell environment for appuser
/home/appuser/.aws/credentials       # AWS CLI credentials (should not be here on servers)
```

**During an incident:** Investigating a potential intrusion. Check `/home/*/.ssh/authorized_keys` for unexpected entries — a backdoor SSH key is a common persistence mechanism. Check shell history:

```bash
cat /home/deploy/.bash_history
ls -lah /home/deploy/.ssh/
```

### `/usr/bin` — User-space binaries (installed programs)

Where package managers install executables available to all users. `/usr/local/bin` is for manually installed software (not managed by the package manager). `/bin` is historically for essential system binaries; on modern systems it is typically a symlink to `/usr/bin`.

```
/usr/bin/python3
/usr/bin/nginx
/usr/bin/htop
/usr/local/bin/myapp     # manually deployed application binary
```

**During an incident:** You need to know which version of a binary is running, or whether the binary has been tampered with.

```bash
which nginx                         # locate the binary
/usr/bin/nginx -v                   # version
md5sum /usr/bin/nginx               # compare hash against known-good
dpkg -S /usr/bin/nginx              # which package owns this file (Debian)
rpm -qf /usr/bin/nginx              # which package owns this file (RHEL)
```

---

## 2. Permission Model

### Reading the permission string

Every file and directory has a 10-character permission string returned by `ls -la`:

```
drwxr-xr-x  2  appuser  appgroup  4096  Apr 5 09:00  data
-rw-r--r--  1  root     root      1234  Apr 5 08:00  config.conf
```

```
Position  Char  Meaning
────────────────────────────────────────────────────────────
1         d     File type: d=directory, -=file, l=symlink
2         r     Owner: read
3         w     Owner: write
4         x     Owner: execute (or enter, for directories)
5         r     Group: read
6         -     Group: no write
7         x     Group: execute/enter
8         r     Other: read
9         -     Other: no write
10        x     Other: execute/enter
```

On **directories** specifically:
- `r` = can run `ls` to list contents
- `w` = can create, rename, or delete files inside
- `x` = can `cd` into it and access files by path

You need all three (`rwx`) to work normally inside a directory. A directory with `r` but no `x` lets you list filenames but not read their contents.

### Numeric (octal) notation

Each permission triplet collapses to a single digit: `read=4`, `write=2`, `execute=1`. Sum the values for each triplet.

```
rwx = 4+2+1 = 7
r-x = 4+0+1 = 5
r-- = 4+0+0 = 4
--- = 0+0+0 = 0
```

Three digits cover owner, group, other:

| Mode | String     | Meaning                                  | Use when                                      |
|------|------------|------------------------------------------|-----------------------------------------------|
| 755  | rwxr-xr-x  | Owner full; group+other read+enter       | Directories, public executables               |
| 644  | rw-r--r--  | Owner read+write; group+other read only  | Config files, static web assets               |
| 600  | rw-------  | Owner read+write only; no one else       | SSH private keys, credential files            |
| 700  | rwx------  | Owner full; no one else                  | Private directories, per-user script dirs     |
| 640  | rw-r-----  | Owner read+write; group read; other none | App configs readable by service group only    |
| 750  | rwxr-x---  | Owner full; group enter+read; other none | Directories accessible to service group only  |

### Setting permissions

```bash
chmod 755 /usr/local/bin/myapp        # numeric
chmod u+x /usr/local/bin/myapp        # symbolic: add execute for owner
chmod g+w /var/app/data               # symbolic: add write for group
chmod o-r /etc/myapp/secrets.conf     # symbolic: remove read from other
chmod -R 750 /var/app/                # recursive
```

### Why 777 is a red flag

`777` (`rwxrwxrwx`) grants every user on the system full read, write, and execute access.

**Concrete security example:** Your app has a file upload endpoint. It writes uploads to `/var/app/uploads/` which was lazily set to `777`. An attacker uploads a PHP web shell — a file containing `<?php system($_GET['cmd']); ?>`. Because the directory is world-writable, the file lands successfully. Because the web server can execute anything in that path, the attacker browses to `/uploads/shell.php?cmd=id` and now has remote code execution as the web server user. From there they read `/etc/passwd`, find writable credential files, and pivot further.

If the directory had been `750` (owner+group only), the upload would have been rejected outright — the web server process, running as `www-data` and not in the owner's group, would have received `Permission denied`.

**Rule:** The correct permission is the minimum required for the legitimate use case. Use `chown` to assign the right owner before reaching for `chmod`.

---

## 3. User and Group Management

### Key files

**`/etc/passwd`** — one line per user account:
```
appuser:x:1001:1001:Application User:/home/appuser:/bin/bash
```
Fields: `username:password:UID:GID:comment:home:shell`

The `x` in the password field means the actual hash is in `/etc/shadow`. This file is world-readable (programs need to resolve UIDs to names).

**`/etc/shadow`** — password hashes, readable only by root:
```
appuser:$6$rounds=5000$salt$hashhash...:19123:0:99999:7:::
```
Fields: `username:hash:last_changed:min_age:max_age:warn_days:inactive:expire`

The split exists for security: world-readable `/etc/passwd` lets any process look up usernames, but the sensitive hashes are locked in `/etc/shadow`. Without the split, any user could copy `/etc/passwd` and run an offline brute-force attack against every account's password.

**`/etc/group`** — group definitions:
```
appgroup:x:1002:appuser,deploy
```
Fields: `groupname:password:GID:member_list`

### User management commands

```bash
# Create a system user for a service (no login shell, no home dir created by default)
sudo useradd --system --no-create-home --shell /bin/false appuser

# Create a human user with home directory
sudo useradd --create-home --shell /bin/bash deploy

# Set or change a password
sudo passwd deploy

# Modify an existing user
sudo usermod --shell /bin/bash appuser          # change shell
sudo usermod --home /var/app appuser            # change home directory
sudo usermod --lock appuser                     # lock account (prepends ! to hash)
sudo usermod --unlock appuser                   # unlock

# Add user to a supplementary group
sudo usermod -aG sudo deploy          # give sudo access
sudo usermod -aG appgroup appuser     # add to application group
# -a is critical: without it, usermod REPLACES all groups instead of appending

# Delete a user
sudo userdel appuser                  # remove account, keep home dir
sudo userdel -r appuser               # remove account AND home directory

# List users
cat /etc/passwd | cut -d: -f1        # all usernames
getent passwd appuser                 # lookup a specific user
id appuser                            # UID, GID, all groups
```

### Group management commands

```bash
# Create a group
sudo groupadd appgroup

# Delete a group
sudo groupdel appgroup

# List group members
getent group appgroup
grep appgroup /etc/group

# See all groups a user belongs to (takes effect on next login)
groups deploy
id deploy
```

### Incident note

Group membership changes require the user to log out and back in to take effect. For a running service, restart it: `sudo systemctl restart myapp`. The process inherits group membership at start time, not dynamically.

---

## 4. Process and Service Management

### `ps` — snapshot of running processes

```bash
ps aux                        # all processes, all users, full detail
ps aux --sort=-%cpu | head 10 # top 10 CPU consumers
ps aux --sort=-%mem | head 10 # top 10 memory consumers
ps -ef                        # full-format listing with PPID (parent PID)
ps -p 18234                   # info for a specific PID
ps -u appuser                 # all processes owned by appuser
```

Key `ps aux` columns:

| Column  | Meaning                                                              |
|---------|----------------------------------------------------------------------|
| USER    | Owner of the process                                                 |
| PID     | Process ID — used for kill, /proc lookups                           |
| %CPU    | CPU share averaged since start (not instantaneous)                  |
| %MEM    | Percentage of physical RAM in use                                    |
| VSZ     | Virtual memory size (includes memory-mapped files, not all in RAM)  |
| RSS     | Resident Set Size — actual RAM in use. This is the real number.     |
| STAT    | State: S=sleeping, R=running, D=uninterruptible I/O wait, Z=zombie  |
| START   | When the process started                                             |
| TIME    | Total CPU time consumed — high value = worked hard                  |
| COMMAND | Full command line                                                    |

### `top` — live process monitor

```bash
top               # launch interactive view
top -b -n 1       # batch mode, single snapshot (useful in scripts)
```

Key header fields during an incident:

```
load average: 3.12, 2.45, 1.87    # 1/5/15-min load; divide by nproc
%Cpu: 78.3 us  5.1 sy  2.1 wa     # user/sys/iowait — wa >10% = disk bottleneck
MiB Swap: 1156.8 used              # any nonzero swap = RAM exhausted
```

Interactive keypresses: `P` sort CPU, `M` sort memory, `k` kill a PID, `q` quit.

### `kill` — send signals to processes

```bash
kill 18234          # SIGTERM (15) — polite shutdown request
kill -15 18234      # explicit SIGTERM
kill -9 18234       # SIGKILL — immediate, forced, no cleanup
kill -HUP 18234     # SIGHUP — reload config (if app handles it)
killall myapp       # SIGTERM all processes named "myapp"
pkill -u appuser    # SIGTERM all processes owned by appuser
```

**SIGTERM (default):** A request. The process catches it, finishes in-flight work, flushes buffers, closes DB connections, and exits cleanly. Always try this first.

**SIGKILL (`-9`):** Cannot be caught, blocked, or ignored. The kernel destroys the process immediately. No cleanup runs. Risk: corrupted files mid-write, open DB transactions left dangling, temp files not cleaned up. Use only when SIGTERM has failed after a reasonable wait (5–10 seconds).

```bash
# Safe kill sequence
kill 18234
sleep 5
ps -p 18234 && kill -9 18234    # force only if still alive
```

### `systemctl` — service lifecycle management

```bash
sudo systemctl start myapp       # start a stopped service
sudo systemctl stop myapp        # graceful stop (SIGTERM + timeout then SIGKILL)
sudo systemctl restart myapp     # stop then start
sudo systemctl reload myapp      # SIGHUP — reload config without full restart
sudo systemctl status myapp      # current state, last log lines, exit code
sudo systemctl enable myapp      # start on boot
sudo systemctl disable myapp     # do not start on boot
sudo systemctl is-active myapp   # prints "active" or "failed" — scriptable
sudo systemctl daemon-reload     # required after editing any unit file
sudo systemctl reset-failed myapp  # clear failed state after hitting restart limit
```

**Status output fields:**

```
● myapp.service - My Application
   Loaded: loaded (/etc/systemd/system/myapp.service; enabled)
   Active: failed (Result: exit-code) since 2026-04-06 14:01:22; 3min ago
  Process: 18234 ExecStart=/usr/bin/myapp (code=exited, status=1/FAILURE)
```

- `enabled` — will start on boot
- `Result: exit-code` — process returned non-zero
- `status=1/FAILURE` — the actual exit code
- Inline log lines — usually enough to identify the crash reason

### Systemd unit file — auto-restart configuration

File location: `/etc/systemd/system/myapp.service`

```ini
[Unit]
Description=My Application
After=network.target

[Service]
User=appuser
Group=appuser
WorkingDirectory=/var/app
EnvironmentFile=/etc/myapp/env
ExecStart=/usr/bin/myapp --config /etc/myapp/config.yaml
Restart=on-failure
RestartSec=5s
StartLimitIntervalSec=60s
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
```

`Restart=` options:

| Value       | Restarts when...                                                      |
|-------------|-----------------------------------------------------------------------|
| `no`        | Never (default)                                                       |
| `on-failure`| Non-zero exit, killed by signal, watchdog timeout — not on clean exit or `systemctl stop` |
| `on-abnormal` | Signal/watchdog only — not on non-zero exit code                   |
| `always`    | Every exit including clean exit and `systemctl stop`                 |

Use `on-failure` for applications. `always` is rarely correct — it fights `systemctl stop`.

Rate-limit settings prevent infinite crash loops: `StartLimitBurst=3` within `StartLimitIntervalSec=60s` means systemd gives up after 3 restarts in 60 seconds and enters `failed` state.

### Systemd service lifecycle

```
systemctl start myapp
    │
    ▼
Read /etc/systemd/system/myapp.service
    │
    ▼
Evaluate [Unit] dependencies
  After=network.target → wait until network is up
    │
    ▼
Apply [Service] execution context
  Switch to User=appuser, Group=appuser
  Load EnvironmentFile, set WorkingDirectory
  Apply resource limits (LimitNOFILE, MemoryMax, etc.)
    │
    ▼
Run ExecStartPre= commands (if any)
  e.g., pre-flight config check or DB migration
    │
    ▼
Fork and exec ExecStart= command
    │
    ▼
Wait for readiness based on Type=
  simple  → started = ready (default)
  exec    → exec() succeeded = ready
  notify  → app sends sd_notify("READY=1")
  forking → parent exits, child is the daemon
    │
    ▼
Active (running) — systemd holds the main PID
    │
    ▼
Process exits (crash / OOM / signal)
    │
    ▼
Evaluate Restart= setting
  on-failure + nonzero exit → wait RestartSec → retry
  Increment counter against StartLimitBurst
    ├─ Under limit → back to ExecStart
    └─ Over limit  → failed state, stop retrying
```

Systemd is the parent process. It captures stdout/stderr into the journal. The app does not need to daemonize itself or manage a PID file.

---

## 5. Package Management

### Side-by-side reference

| Action                    | Debian/Ubuntu (apt)                          | RHEL/CentOS/Amazon Linux (dnf/yum)         |
|---------------------------|----------------------------------------------|--------------------------------------------|
| Refresh package index     | `apt update`                                 | `dnf check-update` / `yum check-update`    |
| Install a package         | `apt install htop`                           | `dnf install htop`                         |
| Remove a package          | `apt remove htop`                            | `dnf remove htop`                          |
| Remove + purge config     | `apt purge htop`                             | `dnf remove htop` (configs removed by default) |
| Upgrade all packages      | `apt upgrade`                                | `dnf upgrade`                              |
| Search for a package      | `apt search htop`                            | `dnf search htop`                          |
| Show package info         | `apt show htop`                              | `dnf info htop`                            |
| List installed packages   | `dpkg -l`                                    | `rpm -qa`                                  |
| Check if package installed| `dpkg -l \| grep htop`                       | `rpm -q htop`                              |
| Which package owns a file | `dpkg -S /usr/bin/htop`                      | `rpm -qf /usr/bin/htop`                    |
| List files in package     | `dpkg -L htop`                               | `rpm -ql htop`                             |

### Why `apt update` must come first

`apt update` downloads the **package index** from repos in `/etc/apt/sources.list` into `/var/lib/apt/lists/`. Without it, apt works from a stale cached index. Consequences of skipping:

- `E: Unable to locate package` on fresh servers that have never synced
- Wrong version installed from outdated index
- Dependency resolution against stale versions → broken installs
- Security patches missed — you install the vulnerable version even when the patched one is available

`dnf`/`yum` refresh metadata automatically before operations, making this less critical — but still run `check-update` during incidents to ensure you have the current index.

### Incident install sequence

```bash
# Debian/Ubuntu
sudo apt update && sudo apt install -y htop
which htop && htop --version
dpkg -l | grep htop

# RHEL/CentOS 8+ / Amazon Linux 2023
sudo dnf install -y htop
which htop && htop --version
rpm -q htop

# Amazon Linux 2 (htop not in default repos)
sudo amazon-linux-extras install epel -y
sudo yum install -y htop
rpm -q htop
```

### Verification

```bash
which htop          # returns path if on $PATH: /usr/bin/htop
htop --version      # confirms binary executes correctly
type htop           # also finds aliases and functions
```

`dpkg -l` status codes (first two characters):

| Code | Meaning                                  |
|------|------------------------------------------|
| `ii` | Installed and working                    |
| `rc` | Removed but config files remain          |
| `un` | Not installed                            |
| `iU` | Installed but unpacked, not configured   |

### During an incident — diagnostic package commands

```bash
# Find which package provides a missing binary
apt-file search nginx           # Debian (requires: apt install apt-file)
dnf provides /usr/bin/nginx     # RHEL

# Check what a package installed
dpkg -L nginx                   # list all files from package (Debian)
rpm -ql nginx                   # list all files from package (RHEL)

# Verify package file integrity (checks against package database)
dpkg --verify nginx             # Debian: prints files that differ from install
rpm -V nginx                    # RHEL: prints modified files (size, hash, permissions)
# No output = all files intact. Output = something was changed after install.
```

`rpm -V` output format: `S.5....T.  /usr/bin/nginx` means Size, MD5 hash, and mTime changed — a tampered binary. Treat this as a security incident.
