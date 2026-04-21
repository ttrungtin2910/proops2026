# Daily Log — Tin (Trần Trung Tín) — Day 11 — 2026-04-22

## Today's Assignment (Day 11 — Deploy to EC2 + Orchestration Intro)
- [ ] Q1 — Provision t3.micro EC2, install Docker + Compose v2, verify both work
- [ ] Q2 — Pull images from Docker Hub; copy .env securely via scp/heredoc; set chmod 600
- [x] Q3 — Identify 3 most common Compose failures on a fresh Linux server
- [x] Q4 — Open Security Group for app port; understand 0.0.0.0 vs 127.0.0.1 port binding
- [x] Q5 — Run stack detached (-d); verify after reconnect; add restart: unless-stopped
- [x] Q6 — docker swarm init → service create --replicas 2 → docker kill → observe auto-recovery
- [x] Q7 — Explain 4 other orchestration problems beyond health monitoring
- [x] Q8 — Write memory/orchestration.md

## Environment
Windows 11 Pro, Claude Code CLI inside VSCode. EC2: Amazon Linux 2023 t3.micro in default VPC, default subnet, fresh Security Group. Docker 26.x + Docker Compose v2 plugin installed via `dnf install docker` + curl. All Swarm demo commands run on the same EC2 instance. Instance terminated at end of day.

## Completed

- [ ] **Q1 — EC2 provisioning + Docker install:**
  Launched t3.micro using Amazon Linux 2023 in default VPC, no NAT Gateway, no Elastic IP. Security Group: SSH (22) from my IP only, plus service ports. Key install path on AL2023: `sudo dnf install -y docker` → `sudo systemctl start docker && enable` → `sudo usermod -aG docker ec2-user` → `newgrp docker` (applies group without logout). Docker Compose v2 installed as CLI plugin via curl to `$HOME/.docker/cli-plugins/docker-compose`. Verify: `docker version` (must show both Client + Server), `docker compose version`. The critical insight: `EXPOSE` in Dockerfile is metadata only — `-p` in docker run is the actual NAT rule, and the app must bind `0.0.0.0` not `127.0.0.1` inside the container.

- [ ] **Q2 — Image pull + .env transfer:**
  `docker pull <user>/<image>:<tag>` — always use specific tag, never `latest` in production. Two safe methods for .env: (1) `scp -i key.pem .env ec2-user@<IP>:/path/.env` — one command from local machine, encrypted in transit, nothing in terminal history on server; (2) heredoc via SSH — `ssh ec2-user@<IP> 'cat > .env' << 'EOF'` — single-quoted heredoc prevents local shell from expanding `$VAR`. Permissions: `chmod 600 .env` so only the owner can read — `644` default lets every user on the machine read plaintext secrets. Verify: `ls -la .env` must show `-rw------- 1 ec2-user`.

- [x] **Q3 — Three common Compose failures on fresh Linux server:**
  (1) **Image missing:** `pull access denied` or `unable to find image` → image was built locally but not pushed, or private registry not logged into. Fix: `docker login` + `docker compose pull`. (2) **Missing .env:** services start but crash with connection errors or empty config — `docker compose config` reveals empty variables. Fix: copy .env to same directory as compose.yml, verify with `docker compose config` before up. (3) **Port binding:** `bind: address already in use` (port taken by system process) or `bind: permission denied` (ports < 1024 require root on Linux, not enforced on Mac). Fix: `sudo ss -tlnp | grep :<port>` to find blocker, or change host port in compose.yml to > 1024. Fastest debug: `docker compose logs <svc>` — error is almost always in first 10 lines.

- [x] **Q4 — Security Group + port binding:**
  Security Group is a stateful firewall at AWS network layer — it drops packets before they reach the EC2 OS. Container running is irrelevant if SG has no rule for the port. Rule needed: Type=Custom TCP, Port=3000, Source=0.0.0.0/0 (public) or `<my-ip>/32` (private testing). Takes effect immediately, no restart needed. After SG fix, second blocker: `docker ps` showing `127.0.0.1:3000->3000/tcp` means Docker bound to loopback only — traffic from outside can never reach it. Correct binding is `0.0.0.0:3000->3000/tcp`. Root cause in compose.yml: `"127.0.0.1:3000:3000"` vs `"3000:3000"`. Debug order: `curl localhost:3000` on EC2 first (isolates app vs network), then `curl <public-ip>:3000`.

- [x] **Q5 — Detached mode + auto-restart:**
  Without `-d`: process is foreground, attached to SSH session → closing terminal sends SIGHUP to shell → process tree killed → stack stops. `docker compose up -d` forks to background, terminal returns immediately. After reconnect: `docker compose ps` (check status/restarts column), `docker compose logs --tail=50 <svc>` if suspicious. Auto-restart after EC2 reboot: `restart: unless-stopped` in each service in compose.yml — restarts after reboot, does NOT restart after manual `docker compose down`. `restart: always` restarts even after manual stop. Use `unless-stopped` for server deployments — preserves ability to stop intentionally for maintenance.

- [x] **Q6 — Docker Swarm kill + recovery demo:**
  `docker swarm init` → `docker service create --name web --replicas 2 nginx:1.25` → `docker service ps web` (both Running) → `docker ps --filter "name=web"` (get container ID) → `docker kill <ID>` → immediately `docker service ps web`. Output showed: old task `web.2` with `DESIRED STATE=Shutdown / CURRENT STATE=Failed`, new task `web.2` with `DESIRED STATE=Running / CURRENT STATE=Running` (within 1–2 seconds). This is the reconciliation loop: manager continuously compares desired state to actual state, and when they diverge, acts immediately to close the gap. Cleanup: `docker service rm web && docker swarm leave --force`.

- [x] **Q7 — Four other orchestration problems:**
  (1) **Scheduling:** without orchestrator, manually SSH each machine and guess available resources — wrong placement = OOM. Orchestrator tracks CPU/RAM per node, places automatically. (2) **Service discovery:** hardcoded IPs break when containers restart on new IPs. Orchestrator provides internal DNS — `api` calls `db:5432` by name, regardless of which node or IP. (3) **Rolling deployments:** `docker compose down` + `up` = full downtime; bug hits all users at once. Orchestrator replaces one replica at a time, keeps old running until new passes health check, stops rollout on failure. (4) **Scaling:** SSH every machine, edit files, restart manually. Orchestrator: one command across all nodes, load balancer picks up new replicas automatically.

- [x] **Q8 — memory/orchestration.md written:**
  Five problems as short paragraphs (what breaks + what orchestrator does), "What I Saw Today" section (Swarm kill demo + DESIRED/CURRENT STATE output), Compose vs Swarm vs K8s 3-column table (6 dimensions), one sentence on why K8s next.

## Extra Things Explored

- **Docker Swarm concepts (deeper dive):** Asked two follow-up questions: "Docker Swarm là gì?" and "Mục đích và ví dụ cụ thể của Docker Swarm?". Clarified the manager/worker node split, the routing mesh (all replicas receive traffic via same port), and when to use Swarm vs K8s. Built a concrete multi-service example with overlay network, postgres:15 at 1 replica (stateful) and API at 3 replicas (stateless). Mental model: Swarm solves the 5 problems but lacks HPA, fine-grained RBAC, and the

## Artifacts Built Today
- [x] `memory/orchestration.md` — 5 problems, Swarm demo observations, Compose vs Swarm vs K8s table, why K8s next
- [x] `daily-logs/day-11.md` — this file

## How I Used Claude Code Today

Heavily hands-on day split into two parts. Part 1 (Q1–Q5) was all about EC2 deployment mechanics — every question was a real problem you hit in sequence when deploying for the first time: server setup → image transfer → stack failures → network visibility → process persistence. The value was building a mental checklist rather than memorizing steps: `docker compose config` before `up`, `curl localhost` before debugging network, `chmod 600` before leaving the server.

Part 2 (Q6–Q8) was the conceptual anchor for Week 3. The Swarm kill demo (Q6) made the reconciliation loop concrete in a way that reading never could — watching the `Failed` task and the new `Running` task appear side by side in `docker service ps` output is the image I'll carry into every Kubernetes concept. Q7 then gave the other four problems names and showed exactly where Docker Compose breaks on multi-server setups, which made writing the orchestration.md memory file (Q8) fast — the content was already organized from answering the questions.

## Blockers / Questions for Mentor
- Linear carry-over is now 15 days. Is there a point at which this becomes a blocker for Week 3 milestone tracking, or does it stay open indefinitely?
- The done criteria says "EC2 instance terminated" — the sidebar artifact list says "EC2 stopped (not terminated)". Which is correct for Day 11? I terminated the instance per the done criteria.
- For `restart: unless-stopped` vs `always`: in production K8s, the equivalent is handled by the Pod's `restartPolicy`. Is the pattern the same — `unless-stopped` maps to `OnFailure`, `always` maps to `Always`?

## Self Score
- Completion: 10/10 (all 8 questions done + extra Swarm exploration)
- Understanding: 9/10 (reconciliation loop is now a concrete image, not an abstraction; Compose vs Swarm vs K8s table is clear)
- Energy: 8/10

## One Thing I Learned Today That Surprised Me

`docker kill` on a Swarm replica and watching the replacement appear in under 2 seconds made the orchestration promise real in a way that no diagram had. The part that surprised me was the DESIRED STATE column: it never changes. The manager doesn't react to failures and then update a goal — the goal is always `Running`, and the manager's entire job is to make reality match that goal. The container isn't "restarted" — it's replaced: a new task is created, the dead one is marked Shutdown. This distinction matters because Kubernetes uses the same model everywhere: Pods, Deployments, ReplicaSets all work the same way — declarative desired state, continuous reconciliation. Understanding Swarm first means Day 12 will be about understanding the control plane, not the basic model.

---

## Tomorrow's Context Block

**Where I am:** End of Day 11, Week 3 — EC2 deploy complete, Swarm kill demo complete, memory/orchestration.md written. All 8 questions done. EC2 terminated. Carry-over: Linear issue and feat/w1-* branch still open (15 days). The reconciliation loop (desired state vs actual state) is the mental model to carry into Kubernetes.

**What to do tomorrow (Day 12):** Kubernetes core — read Day 12 brief first. Start a new `memory/kubernetes-core.md`. The one concept I most want to understand: how the Kubernetes control plane (API server, scheduler, kubelet, etcd) maps to the Swarm manager/worker model I saw today — what each component does in the reconciliation loop and why it's split into separate processes instead of one daemon.

**Open question:** Does `restart: unless-stopped` in Docker Compose map to `restartPolicy: OnFailure` in Kubernetes Pod spec — or are they different concepts entirely?
