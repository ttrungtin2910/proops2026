# Daily Log — Tin (Trần Trung Tín) — Day 13 — 2026-04-23

## Today's Assignment (Day 13 — Kubernetes Intermediate: Ingress, ConfigMap, Secret, HPA)
- [x] Q1 — NodePort scaling problem: what breaks at 10+ services (ports, firewall, DNS, TLS)
- [x] Q2 — What an Ingress controller is — a REAL Pod running nginx/Traefik, not an abstract concept
- [x] Q3 — Ingress resource vs Ingress controller: config rule vs the process that enforces it
- [x] Q4 — Host-based vs path-based routing with concrete YAML examples
- [x] Q5 — ConfigMap: hardcoded → decoupled config; `envFrom` vs `valueFrom` both ways
- [x] Q6 — Secret: what it is, base64 encoding vs encryption, RBAC layers, mount methods
- [x] Q7 — RBAC deep dive: Role/ClusterRole/RoleBinding, external stores (Vault, CSI driver)
- [x] Q8 — HPA end-to-end: metrics-server prerequisite, CPU request requirement, HPA YAML v2, cooldown
- [x] Q9 — Cluster Autoscaler: HPA vs CA composition, two independent control loops
- [x] Q10 — Write memory/kubernetes-advanced.md

## Environment
Windows 11 Pro, Claude Code CLI inside VSCode. minikube running — `minikube addons enable ingress` and `minikube addons enable metrics-server` both enabled. Conceptual deep-dive day: all 10 questions answered via structured conversation. YAML manifests written to `memory/kubernetes-advanced.md`. No new `k8s/` scenario files today — memory file is the primary artifact.

## Completed

- [x] **Q1 — NodePort scaling problem:**
  NodePort-per-service breaks at 10+ services across four axes: (1) **Ports** — each service needs a port in 30000–32767; no naming convention means devs need a spreadsheet. (2) **Firewall rules** — each NodePort = one inbound Security Group rule; no pattern, hard to audit. (3) **DNS** — no way to use clean subdomains; clients remember raw `10.0.1.5:30084`. (4) **TLS** — each service needs its own cert or you terminate TLS at every Pod; impossible to centralize. The fix is one Ingress controller on port 443 that handles all routing.

- [x] **Q2 — Ingress controller is a real Pod:**
  The most common misconception: Ingress controller is not a K8s feature, it is a **Pod running nginx or Traefik inside your cluster**. `kubectl get pods -n ingress-nginx` shows it. It listens on 80/443, receives traffic from outside, and forwards to internal Services. On minikube: `minikube addons enable ingress` deploys this Pod. Without it, an Ingress resource is YAML that nobody reads.

- [x] **Q3 — Ingress resource vs Ingress controller:**
  Ingress resource = YAML config (routing rules you write with `kubectl apply`). Ingress controller = Pod running nginx/Traefik that reads those rules and enforces them. Analogous to writing `nginx.conf` without starting nginx — the config exists but nothing enforces it. The controller watches the K8s API for Ingress objects and reloads its config when they change.

- [x] **Q4 — Host-based vs path-based routing:**
  Two modes on the same Ingress object. Host-based: different `host:` values route to different Services — `api.example.com` → api-svc, `admin.example.com` → admin-svc. Path-based: same host, different `path:` values — `example.com/api` → api-svc, `example.com/admin` → admin-svc. Both modes go through **one NodePort (443)** on the Ingress controller — that's the consolidation payoff.

- [x] **Q5 — ConfigMap: two injection methods:**
  Hardcoded env vars in Deployment = one YAML per environment = 3 nearly-identical files for dev/staging/prod. Change to Deployment spec must be replicated manually; PR reviewers diff 300 lines to find one value. ConfigMap decouples config from container spec. Two injection methods: `envFrom.configMapRef` (entire ConfigMap → env vars; zero Deployment changes when config changes) vs `env.valueFrom.configMapKeyRef` (one key, can rename). Use `envFrom` for all-or-nothing; `valueFrom` when pulling from a shared ConfigMap selectively or need to rename keys.

- [x] **Q6 — Secret: encoding not encryption:**
  Secret shape = ConfigMap shape. Values stored as base64 in etcd. `echo -n "supersecret" | base64` → `c3VwZXJzZWNyZXQ=`. `echo -n "c3VwZXJzZWNyZXQ=" | base64 -d` → `supersecret`. Anyone with `kubectl get secret` + `base64 -d` reads the plaintext in one command. **Base64 is encoding (reversible, no key needed) not encryption (requires key to reverse).** What actually protects secrets: (1) RBAC — restrict `get/list` on secrets resource, (2) etcd encryption-at-rest — must be enabled manually, OFF by default on EKS/GKE/AKS, (3) external stores (Vault, AWS Secrets Manager, Azure Key Vault) for production. Mount methods: env var (simple, leaks into `ps aux` + crash dumps) vs volumeMount file (safer, app reads file on demand, not in process listing). Prefer file.

- [x] **Q7 — RBAC: two access control layers:**
  Layer 1 — RBAC inside cluster: Role (namespace-scoped) + RoleBinding attach permissions to user/ServiceAccount. A Role that lists `pods` and `deployments` but NOT `secrets` → developer gets `Forbidden` on `kubectl get secret`, not hidden — actively denied. Layer 2 — External secret stores: Secrets Store CSI Driver is a DaemonSet that pulls values from Vault/AWS SM/Azure KV at Pod start time and mounts them as files. Value never touches etcd. RBAC alone sufficient for small homogeneous teams; external store mandatory when: auditors require rotation log, multiple clusters share credentials, or DBAs/Security team owns the secret without kubectl access.

- [x] **Q8 — HPA end-to-end:**
  Two prerequisites: (1) metrics-server must be running (`kubectl top pods`); without it HPA reports `TARGETS: <unknown>/70%` and does nothing — most common HPA failure mode. (2) `resources.requests.cpu` must be set — HPA formula is `actual_cpu / cpu_request × 100`; no request = division by zero = HPA cannot compute. HPA YAML (autoscaling/v2): `scaleTargetRef` → Deployment, `minReplicas: 2`, `maxReplicas: 10`, `averageUtilization: 70`. Scale-down cooldown: 5 minutes default — pods killed slower than added to prevent flapping under bursty traffic. `kubectl get hpa -w` streams live TARGETS and REPLICAS.

- [x] **Q9 — Cluster Autoscaler: two independent loops:**
  HPA scales Pods; Cluster Autoscaler scales Nodes. They don't know about each other — they compose via the K8s API. Feedback loop: HPA increases replicas → scheduler tries to place Pods → Pods go Pending (0/N nodes available: insufficient cpu) → Cluster Autoscaler detects Pending → calls cloud API (EC2 ASG / Azure VMSS / GCP instance group) to add Node → Node joins, kubelet reports Ready → scheduler places Pending Pods. HPA failure mode: `TARGETS: <unknown>` (metrics-server missing). CA failure mode: Pods stay Pending (CA not installed, or cloud ASG quota hit). minikube = single node, CA has no cloud API to call.

- [x] **Q10 — memory/kubernetes-advanced.md:**
  Written with: 4 object sections (Ingress, ConfigMap, Secret, HPA), each with gap/prerequisite/minimal YAML. ConfigMap vs Secret table. Verbatim correction note on Secret encoding vs encryption. HPA vs CA table with failure modes. 4-row diagnostic lookup table (Ingress 404, HPA unknown, Secret empty, Pods pending). All manifests use `app: web` / namespace `production` — compose directly with `kubernetes-core.md`.

## Extra Things Explored

- **`minikube addons enable ingress` vs `enable metrics-server`:** Understood that both commands deploy actual Pods into the cluster, not just toggle a flag. Ingress addon → `ingress-nginx-controller` Pod in `ingress-nginx` namespace. Metrics-server addon → `metrics-server` Pod in `kube-system`. The `Completed` Pods (`ingress-nginx-admission-*`) are one-shot webhook jobs — not errors.

- **`kubectl delete pod crash-envvar crash-envvar-fixed crash-exit`:** Cleaned up leftover CrashLoopBackOff Pods from Day 12 practice. Confirmed they are bare Pods (no Deployment) — delete is permanent, no re-creation. `Completed` Pods in ingress-nginx left alone (correct behavior).

- **pathType: Prefix vs Exact:** `pathType: Exact` means `/api` matches only `/api`, not `/api/users`. `Prefix` means `/api` matches `/api`, `/api/users`, `/api/v2/...`. A real 404 debugging session will often start here.

## Artifacts Built Today
- [x] `memory/kubernetes-advanced.md` — Ingress, ConfigMap, Secret, HPA, Cluster Autoscaler, diagnostic table
- [x] `daily-logs/day-13.md` — this file

## How I Used Claude Code Today

Day 13 was structured as a Q&A deep-dive into four K8s intermediate objects. Each question built on the previous: Q1–Q4 established why Ingress exists and how it works; Q5 showed ConfigMap as the answer to hardcoded env var sprawl; Q6–Q7 went deep on Secret — and specifically on the encoding-not-encryption distinction that is the most dangerous misconception in K8s security; Q8–Q9 showed the two-layer autoscaling stack (HPA + CA) and why neither works alone.

The memory file (Q10) was written after all concepts were solid — I had the mental model first, then crystallized it into agent memory. The correction note on Secrets is verbatim and marked mandatory because the wrong mental model here is exactly how production clusters get compromised.

## Blockers / Questions for Mentor
- Ingress `rewrite-target` annotation behavior varies between nginx controller versions — what version does minikube ship? Does `/api` strip the prefix before forwarding to the backend?
- HPA scale-down cooldown is 5 minutes by default — is this configurable per-HPA in autoscaling/v2 or only at the controller level?
- Cluster Autoscaler on EKS: do we use the official CA or Karpenter in Week 5? The Karpenter path (no pre-defined Node Groups) seems simpler operationally.

## Self Score
- Completion: 10/10 — all 10 questions done + memory file written
- Understanding: 9/10 — the HPA→CA composition loop and the RBAC+external-store layering are now concrete mental models; the Secret encoding/encryption distinction is locked in
- Energy: 8/10

## One Thing I Learned Today That Surprised Me

The CSI driver pattern for secrets. I assumed "external secret store" meant a sidecar or init container that fetched secrets and wrote them to env vars. The actual pattern is: Secrets Store CSI Driver is a DaemonSet on every Node, registered as a CSI volume driver. When a Pod mounts a `csi:` volume with `secretProviderClass`, the kubelet calls the CSI driver at Pod start, which authenticates with Vault/AWS SM, pulls the value, and mounts it as a file in the Pod — the value never touches etcd, never becomes a K8s Secret object. It's not a workaround; it's a proper volume driver integration. This is why production teams use it: complete audit trail (every pull logged in Vault/AWS SM), rotation works (file updates without Pod restart in some drivers), and the value is never stored in K8s state.

---

## Tomorrow's Context Block

**Where I am:** End of Day 13, Week 3 — Ingress, ConfigMap, Secret, HPA all covered conceptually. `memory/kubernetes-advanced.md` written and indexed. The K8s object model is now: Pod → Deployment → Service → Ingress (HTTP routing), ConfigMap/Secret (config injection), HPA + ClusterAutoscaler (two-layer autoscaling). All manifests compose under `app: web` / namespace `production`.

**What to do tomorrow (Day 14):** Week 3 continues — the one tool I most want to understand is **Helm**. We've been writing raw YAML manifests all week. Helm is the package manager that templates them — instead of maintaining `deployment-dev.yaml`, `deployment-staging.yaml`, `deployment-prod.yaml` separately, you write one chart with a `values.yaml` per environment. I want to understand: what a Chart is (directory structure), what `helm install` does under the hood vs `kubectl apply`, how `values.yaml` maps to template variables, and when Helm is the right tool vs Kustomize.

**Open questions carrying forward:**
- Does nginx Ingress controller strip the path prefix before forwarding? (e.g., does `/api/users` arrive at the backend as `/api/users` or `/users`?)
- Can HPA scale-down cooldown be configured per-HPA in autoscaling/v2?
- EKS Week 5: Cluster Autoscaler or Karpenter?
