# Daily Log — Tin (Trần Trung Tín) — Day 12 — 2026-04-23

## Today's Assignment (Day 12 — Kubernetes Basics: Pod, Deployment, Service)
- [x] Q1 — CrashLoopBackOff: what it means, root causes, kubectl logs + --previous/--tail/--follow
- [x] Q2 — Deployment YAML structure: Deployment spec, Pod template, container array, env vars (inline + valueFrom)
- [x] Q3 — Liveness vs readiness probes: concrete scenario (20s warm-up + intermittent DB), YAML for both
- [x] Q4 — Four Service types: ClusterIP / NodePort / LoadBalancer / ExternalName + NodePort YAML with 3 ports explained
- [x] Q5 — Label selectors: labels, selector mechanism, Endpoints object, rolling update Endpoints behavior
- [x] Q6 — Rolling update mechanics: defaults, max alive/min ready, stalled rollout, rollback command, revisionHistoryLimit
- [x] Q7 — kubectl diagnostic workflow: 5 steps, unique failure signal per step
- [x] Q8 — Write memory/kubernetes-core.md

## Environment
Windows 11 Pro, Claude Code CLI inside VSCode. No cloud cluster today — AWS blocked. All conceptual work done via Claude Code conversation; manifests written by hand into `k8s/` directory. minikube/kind not run during this session — manifest files ready for Day 15 lab.

## Completed

- [x] **Q1 — CrashLoopBackOff:**
  The loop is start→crash→restart→crash. The backoff is exponential: 10s→20s→40s→80s→160s→5m cap — Kubernetes cooling off between restarts to protect the node. Root causes in order: (1) app exits on startup (unhandled exception, bad logic), (2) missing env var, (3) wrong image/entrypoint, (4) OOMKilled (exit 137). First command: `kubectl logs <pod> --previous` — reads logs from the last crashed container, not the current one. `--previous` = last crash instance; `--tail N` = last N lines; `--follow` = live stream, only useful when container is actually running. CrashLoopBackOff → always start with `--previous`, the container crashes too fast for `--follow` to be useful.

- [x] **Q2 — Deployment YAML structure:**
  Five-layer hierarchy: Deployment object → `spec` (replicas, selector, strategy) → `spec.template` (Pod template) → `spec.template.spec` (Pod spec: volumes, serviceAccount) → `spec.template.spec.containers[]` (container spec: image, env, ports, probes, resources). Env vars live at container level, not Pod level — each container has its own `env:` list. Two ways: (a) inline `value: "production"` for non-sensitive config; (b) `valueFrom.configMapKeyRef` / `valueFrom.secretKeyRef` for dynamic or sensitive values. Critical rule: `selector.matchLabels` must exactly match `template.metadata.labels` — Kubernetes validates this at admission; mismatch causes validation error, or in edge cases, Deployment creates Pods it never recognizes as its own → infinite Pod creation.

- [x] **Q3 — Liveness vs readiness probes:**
  Liveness asks "is the container alive?" — fail → **restart**. Check only the process (`/healthz`, always HTTP 200), never DB. Readiness asks "ready for traffic?" — fail → **remove from Service Endpoints, no restart**. Safe to check DB here. Scenario: app warm-up 20s + intermittent DB. `initialDelaySeconds: 25` on liveness (must exceed warm-up, otherwise CrashLoopBackOff before app finishes starting). `initialDelaySeconds: 5` on readiness (start checking early, will fail until ready). `preStop: sleep 5` absorbs kube-proxy propagation delay so no client hits a Pod mid-shutdown. Classic mistake: checking DB in liveness → DB down → liveness fails → restart loop → app never recovers. `0/1 READY` = readiness failing, Pod excluded from Service Endpoints — user traffic never reaches it.

- [x] **Q4 — Four Service types:**
  ClusterIP (default): internal only, `ClusterIP:port`. NodePort: any node IP + `nodePort` (30000–32767). LoadBalancer: cloud LB → external IP (builds on top of NodePort). ExternalName: DNS CNAME, no proxy. NodePort has 3 ports: `port` (Service internal) → `targetPort` (container) → `nodePort` (node external). Omit `nodePort` → K8s assigns random port in range, visible in `kubectl get svc`. LoadBalancer is production-grade internet exposure; NodePort for dev/lab/bare-metal; ClusterIP for anything internal (DB, cache); ExternalName to alias an RDS or SaaS endpoint under an internal DNS name.

- [x] **Q5 — Label selectors + Endpoints:**
  Labels are arbitrary `key=value` pairs on any K8s object — no meaning until a selector queries them. Service `spec.selector` is a continuous query: Endpoints controller watches cluster, adds Pod IPs when Ready=true + labels match, removes them when Terminating. Endpoints object is distinct from Service — Service is the rule, Endpoints is the live IP list. `kubectl get endpoints <svc>` shows actual IPs. During rolling update: new Pods enter Endpoints only after passing readiness (no premature traffic); terminating Pods are removed from Endpoints immediately; `preStop: sleep 5` fills the kube-proxy propagation gap. If `selector.matchLabels` is wrong → Endpoints is empty → 100% of requests hit "no backend" → connection refused. `kubectl get endpoints` with `<none>` is a fast diagnosis for this.

- [x] **Q6 — Rolling update mechanics:**
  Defaults: `maxUnavailable: 25%`, `maxSurge: 25%` (K8s rounds down unavailable, up surge). With replicas:4 → max 5 alive at once, min 3 Ready. If new Pod fails readiness mid-rollout: rollout **stalls** — neither terminates more old Pods (would violate maxUnavailable) nor creates more new Pods (maxSurge exhausted). Does NOT auto-rollback. `kubectl rollout status` shows it stuck. `kubectl rollout undo deployment/web` reuses the previous ReplicaSet — no new image pull. `revisionHistoryLimit: 10` default — old ReplicaSets kept at scale 0. `maxSurge: 100%` = doubles Pod count during rollout → node resource pressure → new Pods fail readiness → stalled rollout + potentially degraded existing version.

- [x] **Q7 — kubectl diagnostic workflow:**
  5-step sequence: (1) `kubectl get pods` → STATUS + RESTARTS + AGE → **which failure category** (crash vs pending vs not-ready); (2) `kubectl describe pod` → Last State exit code + Events → **exit code of last crash + scheduling/image pull failures**; (3) `kubectl logs --previous` → app stdout/stderr → **actual error message from the process**; (4) `kubectl get events --sort-by='.lastTimestamp'` → node-level events → **scheduler failures + disk pressure not attached to Pod**; (5) `kubectl exec -it -- sh` → last resort, container must be Running → **actual runtime env vars, DNS resolution, mounted file content**. ImagePullBackOff ≠ CrashLoopBackOff — former means container never ran so logs are empty; always use `describe` for image pull failures.

- [x] **Q8 — memory/kubernetes-core.md + k8s/ mock project:**
  `memory/kubernetes-core.md` written: Pod/Deployment/Service sections, liveness vs readiness with YAML, 5-step diagnostic workflow, 3 minimal manifests (all labeled `app: web` consistently), 7-row status→command lookup table, key rules section. Additionally built `k8s/app/` (5 manifests: namespace, configmap, secret, deployment with full probes + lifecycle hooks, dual service) and `k8s/scenarios/` (4 broken pods for diagnosis practice: crash-exit, missing-envvar, oom-kill, bad-image).

## Extra Things Explored

- **Mock project `k8s/`:** Went beyond Q8 and built a full diagnostic practice lab. `k8s/app/` has production-grade manifests (ConfigMap, Secret, Deployment with both probes + `preStop` hook + `terminationGracePeriodSeconds`, ClusterIP + NodePort Service). `k8s/scenarios/` has 4 intentionally broken Pods — one per root cause from Q1 — each with inline comments explaining the symptom, the exact diagnostic command, what to look for, and how to fix. Scenario 2 includes both broken and fixed version side-by-side so you can compare live.

- **`preStop` + `terminationGracePeriodSeconds` interaction:** Understood why `preStop: sleep 5` is not just a workaround — it's the correct pattern for absorbing the kube-proxy iptables propagation delay between when Endpoints removes a Pod and when all nodes stop routing to it. Without it, there's a race window where a client can hit a Pod that has already been removed from Endpoints but whose iptables rules haven't been updated yet.

## Artifacts Built Today
- [x] `memory/kubernetes-core.md` — Pod/Deployment/Service, liveness vs readiness, diagnostic workflow, 3 manifests, lookup table
- [x] `k8s/app/` — 5 production-grade manifests (namespace, configmap, secret, deployment, service)
- [x] `k8s/scenarios/` — 4 broken-Pod manifests for diagnostic practice
- [x] `daily-logs/day-12.md` — this file

## How I Used Claude Code Today

All 8 questions were answered via conversation — each was a structured prompt from the Day 12 brief, building on the previous answer. The flow was intentionally sequential: Q1 taught me what CrashLoopBackOff is; Q2 gave me the YAML structure so I knew where to put the fix; Q3 added probes which appeared in the Q8 manifests; Q4–Q5 explained Services and label selectors which explained why Q8's selector/template labels must match; Q6 deepened rolling update mechanics which made Q7's diagnostic workflow make more sense in context.

The mock project (`k8s/`) was an extra ask after Q8 — I wanted to practice immediately rather than just read manifests. Claude Code generated all 9 files and provided a step-by-step lab guide with the exact commands to run for each scenario. The value was that the scenario files are self-documenting: the comment block in each YAML tells me the symptom, the diagnostic command, what to look for, and the fix — so I can use them as a reference when I run the lab later.

## Blockers / Questions for Mentor
- minikube was not installed this session — all manifests are written and ready but not applied to a live cluster. Should I run the lab tonight or carry it to Day 15?
- Q8 done criteria says "performed a rolling update + watched with `kubectl rollout status`" — this requires a live cluster. Flagging that the manifest work is complete but the live cluster exercise is blocked until minikube is set up.
- Day 13 brief previews Ingress, ConfigMap, Secret, HPA. We already used ConfigMap and Secret in today's Deployment manifests — should I pre-read those sections or let Day 13 cover them fresh?

## Self Score
- Completion: 9/10 (all 8 questions done + extra mock project; live cluster exercise blocked on minikube setup)
- Understanding: 9/10 (selector→Endpoints→kube-proxy chain is now a concrete mental model; the `preStop` / graceful shutdown pattern makes sense mechanically)
- Energy: 8/10

## One Thing I Learned Today That Surprised Me

The `preStop: sleep 5` pattern. I assumed Kubernetes gracefully drained connections before killing a Pod. It doesn't — it removes the Pod from Endpoints and sends SIGTERM almost simultaneously, but kube-proxy on every node needs time to update iptables rules. There's a real race window (1–2 seconds) where a client can route to a Pod that K8s has already decided to kill. `preStop: sleep 5` doesn't drain connections — it just sleeps, giving kube-proxy time to catch up before the process actually starts shutting down. The container is still "alive" during those 5 seconds, just idle. This is a production-grade detail that almost every tutorial skips, and it's the kind of thing that causes mysterious 502 errors during deployments.

---

## Tomorrow's Context Block

**Where I am:** End of Day 12, Week 3 — all 8 K8s basics questions complete. `memory/kubernetes-core.md` written. `k8s/app/` and `k8s/scenarios/` ready for lab practice. Live cluster exercise (rolling update + diagnostic scenarios) pending minikube setup. The mental model for Pod→ReplicaSet→Deployment→Service→Endpoints→kube-proxy is solid.

**What to do tomorrow (Day 13):** K8s intermediate — read Day 13 brief first. Topics preview: Ingress, ConfigMap, Secret, HPA. The one primitive I most want to understand: **Ingress**. Today we had NodePort and LoadBalancer to expose services — but both are blunt instruments (one port per service, no path-based routing, no TLS termination at the K8s layer). Ingress is where HTTP routing gets intelligent. I want to understand: what an IngressController is (vs the Ingress resource), how path and host rules work, and why you need both an Ingress object AND a controller running in the cluster for anything to happen.

**Open questions carrying forward:**
- Does `kubectl apply` on an existing Deployment with a new image tag always trigger a rolling update, or only when the image digest changes?
- `revisionHistoryLimit: 10` keeps 10 old ReplicaSets — does each one consume etcd space even at 0 replicas? Is there a cost to keeping many?
