# Docker

Agent instructions: This file is your authoritative reference for all Docker work.
Read the relevant section before writing Dockerfiles, debugging containers, or explaining
Docker concepts. Never answer from general knowledge when this file covers the topic.

---

## 1. Dockerfile Anatomy

Each instruction creates one image layer (except CMD/ENTRYPOINT which are metadata).
Order instructions from LEAST to MOST frequently changed — this is the cache rule.

### Instruction reference

| Instruction | What it does | When to use it |
|-------------|--------------|----------------|
| `FROM`      | Sets the base image. Everything builds on top of this layer. | Always first. Pin to a specific version tag — never `latest` in production. |
| `WORKDIR`   | Sets the working directory for all subsequent instructions. Creates the dir if it doesn't exist. | Set once near the top. Prefer `/app` for application code. |
| `COPY`      | Copies files from build context into the image. Checksums every file — any change invalidates the layer. | Use instead of ADD unless you need tar-extraction or URL fetch. |
| `RUN`       | Executes a shell command and commits the result as a new layer. | Install packages, compile, run build steps. Chain with `&&` to avoid extra layers. |
| `ENV`       | Sets environment variables baked into the image. Visible in `docker history` and `docker inspect`. | Non-sensitive runtime config only (NODE_ENV, PORT). Never passwords or API keys. |
| `ARG`       | Build-time variable, passed via `--build-arg`. Exists only during build, not in the running container. | Build variants (dev vs prod deps), APP_VERSION. Also visible in `docker history` if used in RUN — not safe for secrets. |
| `EXPOSE`    | Documents which port the app listens on. Does NOT publish the port. Pure metadata. | Always declare for documentation and `-P` auto-mapping. Requires `-p HOST:CONTAINER` at runtime to actually publish. |
| `CMD`       | Default command to run when the container starts. Overridden by anything passed after the image name in `docker run`. | The application entrypoint. Use exec form `["node", "app.js"]` not shell form `node app.js` — shell form wraps in `/bin/sh -c` which breaks signal handling. |
| `ENTRYPOINT`| Sets the executable that always runs. CMD becomes default arguments to ENTRYPOINT. Not overridden by `docker run` args (requires `--entrypoint` flag to override). | Use when the container is a dedicated tool. Combine with CMD for default-but-overridable arguments. |
| `USER`      | Switches to a non-root user for all subsequent instructions and the running container. | Always set before CMD in production images. Running as root inside a container is a security risk. |
| `VOLUME`    | Declares a mount point. Creates an anonymous volume at that path if no volume is mounted at run time. | Rarely needed — prefer explicit `-v` mounts at run time. |

### ENTRYPOINT + CMD interaction

```
ENTRYPOINT ["node"]   CMD ["app.js"]    →  runs: node app.js
ENTRYPOINT ["node"]   CMD ["server.js"] →  docker run myapp server.js  →  runs: node server.js
No ENTRYPOINT         CMD ["node","app.js"]  →  docker run myapp /bin/sh  →  overrides to: /bin/sh
```

### Complete working Dockerfile — Node.js, production-grade

Demonstrates: pinned base image, dependencies-before-code cache pattern,
multi-stage build, non-root user, exec-form CMD.

```dockerfile
# ── Stage 1: install production dependencies ──────────────────────────────
FROM node:18.17.0-alpine3.18 AS deps

WORKDIR /app

# COPY package files FIRST — this layer only rebuilds when deps change, not on every code edit
COPY package.json package-lock.json ./

# npm ci: reads lock file strictly, never updates it, faster than npm install, deterministic
# --omit=dev: excludes devDependencies — jest, eslint, webpack have no place in production
RUN npm ci --omit=dev


# ── Stage 2: build (TypeScript / bundler) ─────────────────────────────────
FROM node:18.17.0-alpine3.18 AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules

# COPY source AFTER deps — this layer rebuilds every commit, but npm ci above does not
COPY . .

RUN npm run build


# ── Stage 3: production runtime ───────────────────────────────────────────
FROM node:18.17.0-alpine3.18 AS production

# Create non-root user before copying files so ownership is correct
RUN addgroup --system --gid 1001 nodejs \
    && adduser --system --uid 1001 --ingroup nodejs appuser

WORKDIR /app

# Copy only what the running app needs — no source TS, no devDeps, no build tools
COPY --from=deps    /app/node_modules ./node_modules
COPY --from=builder /app/dist         ./dist
COPY package.json ./

USER appuser

# Documentation only — does NOT publish the port
EXPOSE 3000

# Exec form: node receives SIGTERM directly from Docker, enabling graceful shutdown
CMD ["node", "dist/server.js"]
```

### Companion .dockerignore

Must exist alongside every Dockerfile. Processed before the build context is sent to the
daemon — reduces context from 400MB to ~2KB for a typical Node.js project.

```
node_modules
npm-debug.log
yarn-error.log

dist
build
.next
.nuxt

coverage
.nyc_output

.eslintrc*
.prettierrc*
jest.config.*

.git
.gitignore
.github

Dockerfile
Dockerfile.*
.dockerignore

.DS_Store
Thumbs.db

.env
.env.*
!.env.example
*.pem
*.key
*.cert
secrets/

logs
*.log

.idea
.vscode

README.md
docs/
```

---

## 2. Layer Cache

### How it works

Every Dockerfile instruction produces a layer identified by a cache key:

```
cache key = hash(instruction text + parent layer hash + file checksums if COPY/ADD)
```

Docker evaluates instructions top to bottom. On rebuild:
- If cache key matches a stored layer → **CACHE HIT** — use stored layer, ~0ms
- If cache key does not match → **CACHE MISS** — execute instruction, all subsequent layers
  are also forced to rebuild regardless of whether they changed

**One miss invalidates everything below it.** This is the single most important
fact about Docker layer caching.

### What triggers cache invalidation

| Instruction | Invalidated when |
|-------------|-----------------|
| `FROM`      | Base image digest changes (new pull) |
| `RUN`       | The instruction string changes |
| `COPY`      | Checksum of ANY file in the source path changes |
| `ADD`       | Same as COPY, plus URL content changes |
| `ENV`       | The instruction string changes |
| `WORKDIR`   | The path string changes |

### Correct instruction order — stable cache

Order from least-volatile to most-volatile:

```
FROM        ← changes: when upgrading Node version (monthly/yearly)
WORKDIR     ← changes: almost never
COPY package*.json ./   ← changes: when adding/removing npm packages (weekly)
RUN npm ci              ← changes: only when package files above change (cache HIT on code edits)
COPY . .                ← changes: every commit (intentional — this is the volatile layer)
RUN npm run build       ← changes: every commit (depends on volatile layer above)
CMD                     ← changes: rarely
```

### Wrong order — what it costs

```dockerfile
# WRONG: code before deps
COPY . .          ← any file change (including app.js) invalidates this layer
RUN npm install   ← forced to re-run on EVERY code change — 2-3 minutes wasted
```

```dockerfile
# RIGHT: deps before code
COPY package*.json ./   ← only package files — stable
RUN npm ci              ← cache HIT when only app.js changes
COPY . .                ← volatile, but only COPY (~0.5s), not npm install
```

**Result: changing one line in app.js goes from 3 minutes to under 5 seconds.**

### Verifying cache hits

```bash
# Build with plain progress to see CACHED vs executed layers
docker build --progress=plain -t myapp . 2>&1 | grep -E "CACHED|RUN|COPY"

# Typical output on a code-only change (correct Dockerfile):
# #3 CACHED          ← COPY package*.json — not changed
# #4 CACHED          ← RUN npm ci — not changed
# #5 COPY . .        ← rebuilt (code changed) — fast
# #6 RUN npm run build ← rebuilt — depends on code

# Force full rebuild (no cache) for clean baseline timing
docker build --no-cache -t myapp .
```

---

## 3. Core Commands

### docker build

```bash
docker build [OPTIONS] PATH

# Standard build
docker build -t myapp:1.2.3 .

# Key flags:
# -t NAME:TAG       tag the resulting image
# --no-cache        bypass all layer cache — use for baseline timing or forced fresh install
# --progress=plain  show full build output (default is "auto" which collapses output)
# --build-arg K=V   inject ARG values
# --file, -f        specify Dockerfile path when not named "Dockerfile"
# --target STAGE    stop at a specific multi-stage build stage

docker build --no-cache --progress=plain -t myapp:latest .
docker build --build-arg NODE_ENV=development -t myapp:dev .
docker build --target deps -t myapp:deps-only .     # build only the deps stage
```

### docker run

```bash
docker run [OPTIONS] IMAGE [COMMAND]

# Key flags:
# -d                detach — run container in background, print container ID
# -p HOST:CONTAINER publish port (creates NAT rule: host traffic → container)
# -e KEY=VALUE      inject environment variable at runtime
# --env-file FILE   inject all KEY=VALUE pairs from file
# --name STRING     assign a name instead of random adjective_noun
# -it               interactive + tty — use for shells and interactive tools
# --rm              auto-remove container when it exits — use for one-shot commands
# -v HOST:CONTAINER mount a host directory or named volume into the container
# --network NAME    attach to a specific Docker network
# --memory 512m     set memory limit (triggers OOMKiller if exceeded)

docker run -d -p 3000:3000 --name myapp --env-file .env myapp:latest
docker run --rm -it --entrypoint sh myapp:latest      # explore image interactively
docker run --rm -e DB_URL=postgres://... myapp:latest node migrate.js
```

### docker exec

```bash
docker exec [OPTIONS] CONTAINER COMMAND

# Attaches a NEW PROCESS to an already-running container's namespaces.
# Does not need SSH. Does not start a new container.

# Key flags:
# -it               interactive + tty — required for shell sessions
# -e KEY=VALUE      set additional env vars for this exec process only
# -w PATH           set working directory for this exec process

docker exec -it myapp /bin/sh               # open shell (Alpine — use sh not bash)
docker exec myapp env | grep DB             # check env vars of running container
docker exec myapp cat /proc/1/environ | tr '\0' '\n'  # env vars of PID 1 (the app)
docker exec -it myapp node -e "require('./config')"   # test module loading
```

### docker logs

```bash
docker logs [OPTIONS] CONTAINER

# Retrieves stdout/stderr captured by Docker daemon.
# Works on running AND stopped containers.

# Key flags:
# --tail N          last N lines only
# --follow, -f      stream logs in real time (like tail -f)
# --timestamps      prefix each line with timestamp
# --since TIME      logs since a timestamp or relative duration (e.g. 30m, 2h)

docker logs --tail 50 --timestamps myapp
docker logs -f myapp                        # stream — Ctrl+C to stop
docker logs --since 10m myapp | grep ERROR  # last 10 minutes, filter errors
```

### docker ps

```bash
docker ps [OPTIONS]

# Key flags:
# -a                show all containers including stopped ones
# -q                quiet — print only container IDs (useful in scripts)
# --format          custom output format
# --filter          filter by status, name, label, etc.

docker ps                                          # running only
docker ps -a                                       # all including stopped
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
docker ps -aq --filter status=exited               # IDs of all stopped containers
```

### docker stop / docker rm / docker rmi

```bash
# Stop a running container gracefully (SIGTERM, wait 10s, then SIGKILL)
docker stop myapp
docker stop --time 30 myapp                        # give 30s before SIGKILL

# Remove a stopped container (frees container layer, not the image)
docker rm myapp
docker rm -f myapp                                 # force-stop then remove

# Remove all stopped containers
docker rm $(docker ps -aq --filter status=exited)

# Remove an image (frees disk space — only works if no containers use it)
docker rmi myapp:1.2.3
docker rmi -f myapp:latest                         # force — removes even if tagged elsewhere

# Remove all dangling images (untagged layers from failed/replaced builds)
docker image prune
docker image prune -a                              # remove ALL unused images
```

### docker pull / docker tag / docker push

```bash
# Pull image from registry to local daemon cache
docker pull node:18.17.0-alpine3.18

# Tag an existing image with a new name (creates alias, does not copy layers)
docker tag myapp:latest registry.example.com/team/myapp:1.2.3

# Push to registry (must be tagged with registry hostname for non-Docker Hub)
docker push registry.example.com/team/myapp:1.2.3
```

### docker cp

```bash
# Copy files between host and container — works on running AND stopped containers
# Does not require exec or shell inside the container

docker cp CONTAINER:SRC HOST_DST
docker cp HOST_SRC CONTAINER:DST

docker cp myapp:/app/logs/error.log ./error.log       # extract log for analysis
docker cp myapp:/app/config/ ./container-config/      # extract entire directory
docker cp ./debug.js myapp:/app/debug.js              # inject script for testing
docker cp /usr/bin/curl myapp:/tmp/curl               # inject binary into distroless image
```

### docker inspect

```bash
# Returns full JSON metadata about a container or image

docker inspect CONTAINER_OR_IMAGE

# Extract specific fields with --format (Go template syntax)
docker inspect --format '{{json .State}}' myapp | python3 -m json.tool
docker inspect --format '{{.State.ExitCode}}' myapp
docker inspect --format '{{.State.OOMKilled}}' myapp
docker inspect --format '{{json .Config.Env}}' myapp
docker inspect --format '{{json .Config.Cmd}}' myapp
docker inspect --format '{{.NetworkSettings.IPAddress}}' myapp
```

### docker port / docker history

```bash
# Show active port mappings for a running container
docker port myapp
# 3000/tcp -> 0.0.0.0:3000

# Show image build history — reveals every instruction ever executed including ENV values
# This is why secrets in Dockerfile are a permanent leak
docker history --no-trunc myapp
```

---

## 4. Port Mapping and Network Isolation

### Network namespace isolation — one sentence

Each container gets its own network namespace: its own `lo` (127.0.0.1), its own `eth0`
(e.g. 172.17.0.2), and its own port space — so port 3000 inside the container is
invisible to the host until you explicitly publish it with `-p`.

### What this means in practice

```
Host machine:
  eth0: 192.168.1.100
  lo:   127.0.0.1        ← host's localhost

  docker0 bridge: 172.17.0.1
    └── Container A:
          eth0: 172.17.0.2   ← container's real IP (Docker-assigned)
          lo:   127.0.0.1    ← container's own localhost (NOT the host's)
          :3000              ← only exists inside this namespace

curl localhost:3000 (from host) → reaches HOST's port 3000 → nothing listening → refused
curl 172.17.0.2:3000 (from host, Linux only) → reaches container directly (no mapping needed)
```

### `-p HOST_PORT:CONTAINER_PORT` — what Docker actually does

```bash
docker run -p 3000:3000 myapp
```

1. Binds `0.0.0.0:3000` on the host (any interface)
2. Creates iptables NAT rule: traffic arriving at host:3000 → DNAT → 172.17.0.2:3000
3. Enables IP forwarding on the host kernel

```bash
# Verify the iptables rule (Linux host, requires sudo)
sudo iptables -t nat -L DOCKER -n
# DNAT  tcp  --  0.0.0.0/0  0.0.0.0/0  tcp dpt:3000 to:172.17.0.2:3000
```

### Port mapping variants

```bash
-p 3000:3000            # host:3000 → container:3000
-p 8080:3000            # host:8080 → container:3000 (app still listens on 3000 internally)
-p 127.0.0.1:3000:3000  # only localhost on host, not accessible from LAN
-p 3000:3000 -p 9229:9229  # multiple ports (app port + Node.js debugger)
-P                      # auto-map all EXPOSE'd ports to random ephemeral host ports
```

### EXPOSE vs -p — they are completely different

```
EXPOSE 3000   →  metadata only
              →  written to image manifest
              →  enables -P auto-mapping
              →  does NOT create any iptables rule
              →  does NOT allow any traffic in
              →  container still unreachable from host

-p 3000:3000  →  creates the actual NAT rule
              →  traffic flows
              →  EXPOSE not required for -p to work
```

**Rule:** `-p` alone is sufficient. `EXPOSE` is convention (document it, but don't rely on it for security — it provides no actual isolation).

### App must bind 0.0.0.0, not 127.0.0.1

```javascript
// WRONG — binds only container's loopback, Docker NAT cannot reach it
app.listen(3000, '127.0.0.1')

// RIGHT — binds all interfaces in container's namespace, Docker NAT reaches it
app.listen(3000, '0.0.0.0')
app.listen(3000)              // defaults to 0.0.0.0
```

```bash
# Verify app is bound to 0.0.0.0 inside container
docker exec myapp ss -tlnp | grep 3000
# LISTEN  0.0.0.0:3000    ← correct
# LISTEN  127.0.0.1:3000  ← wrong: fix app code
```

### Check active port mappings

```bash
docker port myapp                        # show all mappings for container
docker port myapp 3000                   # show mapping for specific container port
docker ps --format "table {{.Names}}\t{{.Ports}}"  # all containers
ss -tlnp | grep LISTEN                   # verify host is listening (from host)
```

---

## 5. Image vs Container Distinction

### The analogy

```
Image     =  class definition  =  ISO file  =  blueprint
Container =  object instance   =  running VM =  process with isolated namespaces

One image → many simultaneous containers (all independent)
One class → many objects         (all independent state)
```

### What each command shows

```bash
docker images              # lists images stored in local daemon cache
# REPOSITORY   TAG          IMAGE ID       CREATED        SIZE
# myapp        1.2.3        a3f9c2b81d44   2 hours ago    98MB
# myapp        latest       a3f9c2b81d44   2 hours ago    98MB   ← same ID, two tags
# node         18.17.0-...  f7c3e5a12b89   3 days ago     174MB

docker ps -a               # lists containers (running and stopped)
# CONTAINER ID   IMAGE          COMMAND         STATUS              NAMES
# d9e4f5c61a22   myapp:1.2.3   "node dist/..."  Up 2 hours          myapp_prod
# b2c3d4e51f11   myapp:1.2.3   "node dist/..."  Up 2 hours          myapp_staging
# a1b2c3d4e5f6   myapp:1.2.3   "node dist/..."  Exited (1) 5m ago   myapp_debug
```

Two containers running from the same image → identical starting filesystem, independent
runtime state (processes, memory, written files).

### Image layers and the copy-on-write container layer

```
Image (read-only layers, shared between all containers using this image):
  Layer 0: node:18.17.0-alpine3.18 base         (174MB, on disk once)
  Layer 1: WORKDIR /app                          (0MB)
  Layer 2: COPY package*.json + RUN npm ci       (45MB, on disk once)
  Layer 3: COPY source files                     (1MB, on disk once)

Container A (adds one writable layer on top):
  Writable layer: files written at runtime       (grows as app writes files, logs, tmp)
  ↓ reads through to image layers for everything else

Container B (adds its own writable layer):
  Writable layer: independent from Container A
  ↓ reads through to the same shared image layers

When a container writes to a file that exists in an image layer:
  → Docker copies the file into the container's writable layer (copy-on-write)
  → The image layer is unchanged
  → Other containers see the original file
```

### Lifecycle: image → container → gone

```bash
# Image persists until explicitly removed
docker rmi myapp:1.2.3

# Container's writable layer is lost when the container is removed
docker rm myapp_debug        # writable layer deleted — any files written at runtime are gone
                             # image layers untouched — other containers unaffected

# To persist data written at runtime: use volumes
docker run -v /host/data:/app/data myapp     # mount host directory
docker run -v mydata:/app/data myapp         # mount named volume (managed by Docker)
```

### Disk space accounting

```bash
docker system df            # show disk usage by images, containers, volumes
# TYPE            TOTAL   ACTIVE  SIZE      RECLAIMABLE
# Images          8       3       2.1GB     1.4GB (66%)
# Containers      5       2       45MB      30MB (66%)
# Volumes         3       2       1.2GB     0B

docker system prune         # remove stopped containers, dangling images, unused networks
docker system prune -a      # also remove unused images (not just dangling)
```

---

## Secrets and Configuration (cross-cutting concern)

```
Config tier          Where to set                    Examples
───────────────────────────────────────────────────────────────
Build variants       ARG + --build-arg               NODE_ENV, APP_VERSION
Non-secret runtime   -e or --env-file at docker run  PORT, LOG_LEVEL, FEATURE_FLAGS
Secrets              Mounted files /run/secrets/      DB_PASSWORD, JWT_SECRET, API_KEY
                     Docker Secrets (Swarm)
                     Secrets Manager (AWS/GCP/Vault)
```

**Never:** `ENV DB_PASSWORD=...` in Dockerfile → permanent in image history, readable
by anyone with `docker history --no-trunc` or `docker inspect`.

**Never:** `ARG DB_PASSWORD` used inside `RUN ./setup.sh $DB_PASSWORD` → also in history.

**Correct secret injection at runtime:**

```bash
# Via env var (acceptable for dev, not ideal for prod)
docker run --env-file .env myapp

# Via mounted file (production pattern)
docker run -v /run/host-secrets/db_password:/run/secrets/db_password:ro myapp

# App reads from file:
# fs.readFileSync('/run/secrets/db_password', 'utf8').trim()
```

**.env must be in both .gitignore AND .dockerignore.** A `.env` committed to git is
permanent in git history (requires filter-repo to purge). A `.env` not in .dockerignore
gets copied into the image by `COPY . .` and is readable by anyone with the image.

---

## Debugging Cheatsheet

```bash
# Container exits immediately
docker ps -a                          # check STATUS and exit code
docker logs $CID                      # read stdout/stderr — the actual error is here
docker inspect --format '{{json .State}}' $CID | python3 -m json.tool

# Exit codes:
# 0   = clean exit (process finished, not a crash)
# 1   = app error (read logs)
# 127 = command not found (wrong CMD binary or typo)
# 137 = SIGKILL — OOMKilled or docker kill
# 143 = SIGTERM — docker stop

# Can't reach app on localhost
docker port $CID                      # is port mapping active?
docker exec $CID ss -tlnp             # is app bound to 0.0.0.0 or 127.0.0.1?
docker exec $CID curl localhost:3000  # does it work from inside?

# Debug inside running container
docker exec -it $CID /bin/sh          # Alpine: sh, Debian/Ubuntu: bash
docker exec $CID env | grep -v PATH   # check env vars
docker exec $CID ps aux               # check running processes
docker exec $CID nc -zv db-host 5432  # test network reachability

# No shell in image (distroless)
PID=$(docker inspect --format '{{.State.Pid}}' $CID)
sudo nsenter -t $PID --mount --uts --ipc --net --pid -- /bin/sh

# Extract files without shell
docker cp $CID:/app/logs/error.log ./error.log
docker cp $CID:/app/config/ ./config-dump/
```
