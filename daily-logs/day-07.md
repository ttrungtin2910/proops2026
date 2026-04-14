# Daily Log — Tin (Trần Trung Tín) — Day 7 — 2026-04-14

## Today's Assignment (Day 7 — Docker Core: Dockerfile, Image, Build, Run, Exec)
- [x] Watch Video 1 (0:13:00–1:51:00) — Docker fundamentals: image, container, Dockerfile, layer cache, core commands
- [x] Watch Video 2 (0:00–1:06:00) — Full practice: Dockerfile → build → run → debug → exec
- [x] Verify Docker installation: `docker run hello-world` succeeds
- [x] Q1 — Environment drift: 5 sources + why Docker solves it
- [x] Q2 — Build context + .dockerignore: what gets sent to daemon, correct Node.js setup
- [x] Q3 — Layer cache: how it works, why wrong order costs 3 minutes, "dependencies before code" rule
- [x] Q4 — Container exits immediately: `docker ps -a` → `docker logs` → `docker inspect` debug flow
- [x] Q5 — Port mapping: network isolation, `-p HOST:CONTAINER`, EXPOSE vs -p
- [x] Q6 — Secrets in Dockerfile: layer permanence, `--env-file`, ARG vs ENV, Docker secrets
- [x] Q7 — `docker exec`: how it attaches to namespaces, debug workflow, Alpine `/bin/sh`, `docker cp`
- [x] Q8 — Write `memory/docker.md` with all 5 required sections
- [ ] Create first real Linear training issue via `/create-linear-issue` (carry-over)
- [ ] Open `feat/w1-*` branch following IRD-001 commit standards (carry-over)

## Environment
Docker Desktop (WSL2 backend) on Windows 11 Pro. Docker daemon running, verified with `docker run hello-world`. All discovery chain commands run inside WSL2 terminal.

## Completed

- [x] **Q1 — Environment drift:** Five sources: Node.js version (nvm installs differ per machine), package dependencies (node_modules built by different npm versions produce different trees), environment variables (missing DB_URL silently changes behavior), config file paths (hardcoded `/home/user/app` vs `/Users/user/app`), OS-level libraries (native modules compile against host libc — darwin/arm64 binary is not linux/x86_64 compatible). At 50 engineers: 50 Node versions × 3 OS types × 2 package managers = hundreds of environment combinations. Docker solves this by making the environment itself the artifact — the Dockerfile is the spec, the image is the built environment, every machine runs identical bytes.

- [x] **Q2 — Build context + .dockerignore:** Build context = everything in the directory is tar'd and sent to the Docker daemon before any instruction runs. `docker build .` — the `.` is the context path, not the Dockerfile path. A Node.js project without `.dockerignore` sends `node_modules/` (400MB), `.git/`, `.env`, `coverage/`, `dist/` to the daemon on every build. The `.dockerignore` is processed before the tar — not during `COPY` — so excluded files never touch the daemon. Key rule: never copy `node_modules` from the host into the image: (1) native modules compile for host OS/arch, (2) devDependencies get included, (3) different machines produce different node_modules trees. Correct pattern: `.dockerignore` excludes `node_modules`, Dockerfile runs `npm ci` inside the image to build clean, reproducible dependencies.

- [x] **Q3 — Layer cache:** Each Dockerfile instruction produces a layer with a cache key: `hash(instruction text + parent layer hash + file checksums for COPY/ADD)`. One cache miss invalidates ALL subsequent layers regardless of whether they changed. Wrong order: `COPY . .` then `RUN npm install` — any change to `app.js` invalidates the COPY layer, which forces npm install to re-run: 3 minutes wasted. Correct order: `COPY package*.json ./` → `RUN npm ci` → `COPY . .`. Result: changing `app.js` gets a CACHE HIT on `npm ci` (package files unchanged) — rebuild drops from 3 minutes to under 5 seconds. Rule: order instructions from least-volatile to most-volatile.

- [x] **Q4 — Container exits immediately debug flow:** Step 1: `docker ps -a` — shows all containers including stopped; read STATUS and EXITED(N) code. Step 2: `docker logs [CID]` — reads stdout/stderr captured by Docker daemon; works on stopped containers; the actual error message is here. Step 3: `docker inspect --format '{{json .State}}' [CID]` — reads ExitCode, OOMKilled, Error. Three most common causes: wrong CMD binary (`Exited(127)` = command not found), missing environment variable (app throws on startup), missing file (COPY path was wrong, `WORKDIR` mismatch). Exit codes: 0=clean, 1=app error, 127=command not found, 137=SIGKILL/OOMKilled, 143=SIGTERM from docker stop.

- [x] **Q5 — Port mapping + network isolation:** Each container has its own network namespace: its own `lo` (127.0.0.1), its own `eth0` (172.17.0.2), its own port space. Port 3000 inside a container is invisible to the host until published. `-p 3000:3000` tells Docker to: (1) bind `0.0.0.0:3000` on the host, (2) create an iptables NAT rule DNAT-ing host:3000 → 172.17.0.2:3000. `EXPOSE 3000` in the Dockerfile is metadata only — it does NOT create any iptables rule, does NOT publish the port, does NOT allow any traffic. `-p` is the only instruction that makes a port reachable. Also: the app must bind `0.0.0.0`, not `127.0.0.1`, inside the container — if it binds only loopback, the Docker NAT rule cannot reach it.

- [x] **Q6 — Secrets in Dockerfile:** `ENV DB_PASSWORD=...` in a Dockerfile bakes the secret into an image layer. Deleting it in a subsequent layer does NOT remove it — the original layer is still in the image history. `docker history --no-trunc` reveals every ENV and RUN value ever set. `ARG DB_PASSWORD` used inside a `RUN` command is also permanent in history. Correct patterns: (1) development: `docker run --env-file .env myapp` — .env file must be in both `.gitignore` and `.dockerignore`; (2) production: mount a secret file at `/run/secrets/db_password` from tmpfs, app reads it with `fs.readFileSync`. Config tiers: ARG = build variants (NODE_ENV, APP_VERSION), ENV = non-sensitive runtime config (PORT, LOG_LEVEL), Secrets = passwords/keys via mounted files or secrets manager.

- [x] **Q7 — docker exec vs SSH:** `docker exec -it [CID] /bin/sh` attaches a new process to an already-running container's existing namespaces (PID, network, filesystem, IPC). It does not start a new container. No SSH daemon needed — Docker attaches directly via the container runtime. Once inside: `ls -la /app` (filesystem), `ps aux` (processes), `env` (environment variables), `cat /proc/1/environ | tr '\0' '\n'` (PID 1 environment), `curl localhost:3000` (internal connectivity), `nc -zv db-host 5432` (outbound network). Alpine images ship `/bin/sh` not `/bin/bash`. Distroless images have no shell at all — use `docker cp` to extract files, or `nsenter -t [PID] --mount --net --pid -- /bin/sh` from the host to attach via the host kernel. `docker exec` vs `docker run`: exec attaches to a running container, run starts a new one from an image.

- [x] **Q8 — memory/docker.md written:** 5 required sections plus Secrets/Configuration section and Debugging Cheatsheet. Section 1: Dockerfile anatomy (all 10 instructions with one-line rule + ENTRYPOINT/CMD interaction table + complete 3-stage production Dockerfile + companion .dockerignore). Section 2: Layer cache (cache key formula, invalidation table, correct vs wrong instruction order side-by-side, cache verification commands). Section 3: Core commands (build, run, exec, logs, ps, stop/rm/rmi, pull/tag/push, cp, inspect, port/history — key flags + real-world one-liners for each). Section 4: Port mapping and network isolation (namespace diagram, iptables NAT explanation, port variants, EXPOSE vs -p comparison, app binding requirement, verification commands). Section 5: Image vs container distinction (class/object analogy, docker images vs docker ps output, copy-on-write layer diagram, lifecycle, disk accounting).

## Not Completed
| Item | Reason | Days Overdue |
|---|---|---|
| Create Linear training issue | Docker day consumed full session | 11 days |
| Open feat/w1-* branch | Blocked on Linear issue | 11 days |

## Extra Things Explored (Explore Further)

- **Multi-stage builds:** Stage 1 installs all devDependencies + runs tests. Stage 2 copies only the production build to a clean Alpine image. Final image ~80MB vs ~500MB for a single-stage build. The reason: devDependencies (jest, webpack, typescript, eslint) and the TypeScript source are not copied into the final stage — only `dist/` and `node_modules/` (production only). In CI/CD this matters because: smaller image = faster pull on every deploy, smaller attack surface, no source code in the production artifact. The `--target STAGE` flag lets you build only up to a specific stage (e.g., `docker build --target deps` for the install-only stage).

- **ENTRYPOINT vs CMD — signal handling + PID 1:** Shell form CMD (`CMD node app.js`) wraps the command in `/bin/sh -c node app.js`. The shell becomes PID 1 and the Node.js process is a child. `docker stop` sends SIGTERM to PID 1 (the shell), which does NOT forward it to the Node.js child — Node.js gets SIGKILL after the timeout (10s), dirty shutdown. Exec form CMD (`CMD ["node", "app.js"]`) makes Node.js PID 1 directly. SIGTERM reaches the application, graceful shutdown handlers run. Rule: always use exec form for the final CMD/ENTRYPOINT in production containers.

- **Non-root user in containers:** `USER appuser` in the Dockerfile makes the running process non-root. If a container escape vulnerability is exploited and the attacker breaks out of the container, they land as UID 1001 on the host (limited permissions) instead of root (full host takeover). `--read-only` flag mounts the container filesystem as read-only — any write attempt (malware, exfiltration) fails at the filesystem level. Minimum viable security hardening for production Node.js: non-root USER + read-only root filesystem + `--tmpfs /tmp` (app can still write to /tmp via tmpfs) + `--cap-drop=ALL`.

## Artifacts Built Today
- [x] `memory/docker.md` — Dockerfile anatomy, layer cache, core commands, port mapping, image vs container, secrets config, debugging cheatsheet
- [x] `daily-logs/day-07.md` — this file

## How I Used Claude Code Today
Hands-on Docker day — worked through all 8 discovery questions in sequence, running every command as part of the session. Most valuable: the layer cache explanation (Q3) made the "3 minutes → 5 seconds" difference completely concrete by tracing exactly which layer gets invalidated at each step. The port mapping section (Q5) cleared up a persistent confusion: EXPOSE in Dockerfile and `-p` in docker run look related but are completely unrelated — EXPOSE is documentation, `-p` is the actual NAT rule. The secrets section (Q6) was the most important security concept of the day: image layers are permanent, there is no way to retroactively remove a baked-in secret from a published image.

## Blockers / Questions for Mentor
- Linear training issue and feat/w1-* branch are now 11 days overdue. Day 8 is a design day — is that the right time to complete these, or should they stay in backlog while the mock project design takes priority?
- For the non-root user pattern (Explore Further): in Kubernetes, the securityContext at the Pod level can also enforce non-root. Is the USER instruction in the Dockerfile redundant when running in K8s with securityContext, or should both always be set?
- Multi-stage builds: the `--target STAGE` flag builds up to a specific stage. Is this used in CI to run tests in a test stage before producing the production image, or is it more common to have separate test and production Dockerfiles?

## Self Score
- Completion: 9/10 (all 8 questions + Explore Further; carry-over still open)
- Understanding: 9/10 (layer cache and network isolation are now concrete mechanics, not abstractions)
- Energy: 8/10

## One Thing I Learned Today That Surprised Me

`EXPOSE` in a Dockerfile does absolutely nothing to network traffic. I assumed it was like a firewall rule that opens the port — but it is pure metadata written to the image manifest. The container is still completely unreachable until you pass `-p HOST:CONTAINER` to `docker run`, which creates the actual iptables NAT rule. `EXPOSE` only matters for: (1) documentation so other engineers know which port the app uses, and (2) the `-P` flag on `docker run`, which auto-assigns random host ports to all EXPOSE'd ports. The mental model shift: Dockerfile = what the image IS; `docker run` flags = how the container is CONNECTED to the outside world. These are two entirely separate concerns.

---

## Tomorrow's Context Block

**Where I am:** End of Day 7, Week 2 — Docker Core complete. All 8 discovery questions done plus Explore Further (multi-stage builds, exec-form PID 1 signal handling, non-root USER + --read-only security hardening). Artifact: `memory/docker.md` with 5 required sections + secrets config + debugging cheatsheet. Carry-over: Linear training issue and feat/w1-* branch still open (11 days overdue).

**What to do tomorrow (Day 8):** Design day — Define Mock Project (DOP + IRD + Architecture). Read Day 8 brief first. Before starting: check whether the Linear training issue carry-over should be cleared during this design session (the DOP and IRD for the mock project are exactly what a Linear issue would reference). Cost hygiene: NAT Gateway + OpenVPN EC2 still running.

**Open question:** For the USER instruction in a Dockerfile — is it redundant when Kubernetes enforces non-root via Pod securityContext, or should both always be set as defense-in-depth?
