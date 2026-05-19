# Day 20 Quiz — Scored Results

**Date:** 2026-05-20  
**Total: 19 / 30**  
**Scoring rules:** +1 correct · +1 honest GAP · -1 wrong-but-confident · no negative floor

---

## Per-Question Breakdown

| Q | Score | Verdict | Evidence from memory |
|---|---|---|---|
| Q1 | **0** | Image/container distinction correct. Exit code 0 ✓. But said **"Exit code 138"** — it is 137 (128 + SIGKILL=9). Stated confidently without hedging. | docker.md §16: `137 → OOM or SIGKILL` |
| Q2 | **+1** | "Improve security" is a valid benefit beyond smaller image — build SDK and secrets stay out of the runtime layer. ("Save volume" = same as smaller image, but security credit stands.) | docker.md §11 Multi-Stage Builds |
| Q3 | **-1** | **WRONG — confident.** Said "docker compose down will remove named volumes." It does NOT. Named volumes are kept. Only `docker compose down -v` deletes them. | docker.md §14: `down → containers removed, volumes KEPT` / `down -v → volumes deleted` |
| Q4 | **+1** | Three correct checks in order: same network → service name (not localhost) → container B status + port binding. | docker.md §13, §16 |
| Q5 | **+1** | IGW = bidirectional public traffic. NAT = outbound-only. NAT allows private EC2 to reach internet. Correct. | aws.md §3 VPC, networking-basics.md §3 |
| Q6 | **+1** | "Pods have no self-healing. Deployment gives Self-Healing, Rolling Rollouts, Declarative Scaling." Matches memory exactly. | kubernetes-core.md Pod/Deployment section |
| Q7 | **+1** | `logs --previous` → stack trace. `describe pod` → exit code. `get events` → cluster-level blocks. Order matches CrashLoopBackOff lookup table. | kubernetes-core.md Diagnostic Lookup Table |
| Q8 | **+1** | Readiness probe failing → alive but removed from Service Endpoints, no restart. vs Liveness → restart container. | kubernetes-core.md Liveness vs Readiness section |
| Q9 | **+1** | ClusterIP internal DB ✓ · LoadBalancer public AWS ✓ · NodePort minikube dev ✓ | kubernetes-core.md Service table |
| Q10 | **+1** | Max alive = 13 (10 + ceil(2.5)=3) ✓. Min ready = 8 (10 − floor(2.5)=2) ✓. | kubernetes-core.md Deployment rolling update defaults |
| Q11 | **+1** | `kubectl rollout undo deployment/<name>`. K8s reuses previous ReplicaSet (revisionHistoryLimit:10). | kubernetes-core.md Deployment section |
| Q12 | **0** | Mechanics right: apply = create-or-update, create = fails if exists. **Missing: "when does the difference matter"** (CI/CD pipelines — create fails on 2nd run, apply succeeds). Half the question unanswered. | kubernetes-core.md / general K8s knowledge |
| Q13 | **+1** | Resource = config definition. Controller = software executing it. Neither functional without the other. Correct. | kubernetes-advanced.md Ingress section |
| Q14 | **-1** | **WRONG — confident.** Q14 asks to confirm/explain the base64 ≠ encryption fact about Secrets. A14 says "Pods do not have CPU resource requests defined" — **completely off-topic**, answered a different question. | kubernetes-advanced.md Secret section: `"CORRECTION — MEMORIZE THIS: Secrets are NOT encrypted by default"` |
| Q15 | **-1** | **WRONG — confident.** Said `kubectl get deployment -o yaml`. Correct answer: `kubectl top pods` — this is the command that reveals whether metrics-server is running. A deployment yaml shows nothing about HPA metric collection. | kubernetes-advanced.md: `"HPA stuck <unknown>/70% → kubectl top pods → metrics-server not running"` |
| Q16 | **+1** | HPA scales Pods (replicas) on metrics. CA scales Nodes (VMs) on Pending Pods. Correct split. | kubernetes-advanced.md HPA vs Cluster Autoscaler table |
| Q17 | **+1** | Same namespace: `b.default.svc.cluster.local` ✓. Different namespace: `b.namespace-b.svc.cluster.local` ✓. | kubernetes-project.md §3 in-cluster DNS pattern |
| Q18 | **+1** | `kubectl rollout restart deployment/<name>`. Correct — ConfigMap changes do not auto-reload running Pods. | kubernetes-advanced.md ConfigMap section + standard K8s behavior |
| Q19 | **+1** | "References a ConfigMap or Secret that doesn't exist or can't find the key." `kubectl describe pod <name>`. Matches lookup table. | kubernetes-advanced.md Diagnostic Lookup Table |
| Q20 | **+1** | Chart = source code (versioned package). Repository = app store (remote server). Release = running application (named installed instance). Non-circular, matches definitions. | helm-basics.md §1 Three Core Concepts |
| Q21 | **+1** | `kubectl get svc -l app.kubernetes.io/instance=my-redis`. Valid approach, more precise than memory file's `grep` method. | helm-basics.md §5 How to Find Service Name |
| Q22 | **+1** | `helm rollback` never rewrites history — creates a new revision (copy of target). `helm history` shows revision N+1. | helm-basics.md §8 Release History Model |
| Q23 | **+1** | StatefulSet provides stable network identity, fixed PVC association, ordered deployment. "Identity, fixed storage, order" matches. | helm-basics.md §9 + general K8s StatefulSet knowledge |
| Q24 | **0** | Got LBs ✓ and EBS Volumes ✓. Said **Security Groups** instead of **VPC orphan**. Memory names the three as: EBS volumes, Load Balancers, VPC. Security Groups are cleaned up with the VPC, not a separate check. | eks-practice.md §9 Delete sequence Step 4 |
| Q25 | **+1** | `tail -f` breaks in production because it follows the inode — after log rotation the old inode still points to the rotated file, monitoring silently stops. `tail -F` follows the filename, reconnects after rotation. | scripts/monitor-logs.sh inline comment: `tail -F (uppercase): reconnects after rotation. tail -f: loses track, alert shuts off silently` |
| Q26 | **+1** | Two causes: missing PATH + wrong working directory. Simulate with `env -i`. Correct. (`env -i` technique is not in memory file but is accurate.) | bash-scripting.md §6 PATH Hygiene |
| Q27 | **0** | Gave WHY correctly: "verifies blast radius, catches logical errors." **Missing the implementation pattern** — the `run()` wrapper in deploy.sh that prints commands in dry-run mode instead of executing them. Half the question unanswered. | scripts/deploy.sh `run()` function lines 27–33 |
| Q28 | **+1** | tfstate = JSON mapping code to real-world resources. If deleted, infra keeps running but Terraform loses all memory → must `terraform import` everything back. | iac-basics.md §3 State File Rules |
| Q29 | **+1** | Terraform creates EC2, Ansible installs nginx. Split = Orchestration (Provisioning) vs Configuration Management. | iac-basics.md §1 Two-Tool Rule and §6 Decision Table |
| Q30 | **0** | Listed the three correct files: `.terraform/`, `*.tfstate`, `*.tfvars`. **Did not explain why each must not be committed** — which was explicitly asked. `.terraform/` = 100MB binaries. `tfstate` = resource IDs + secrets. `*.tfvars` = actual credential values. | iac-basics.md §4 Gitignore for Terraform |

---

## Three Confident Wrongs — Root Cause

These are the -1 answers. Each one was stated without any hedge.

**Q3 — compose down removes named volumes:**  
The correct rule is `down` keeps volumes, `down -v` deletes them. This matters in production: running `compose down` expecting to wipe the database won't do it. Fix: run `docker compose down -v` when a clean-state reset is needed.

**Q14 — answered a different question:**  
A14 answered a question about CPU resource requests while Q14 asked about base64 ≠ encryption in Secrets. The correct answer: base64 is encoding (reversible, one command to decode), not encryption. Anyone with `kubectl get secret` access can run `base64 -d` and read the value. Real protection requires etcd encryption-at-rest + RBAC.

**Q15 — wrong command for HPA unknown metrics:**  
`kubectl get deployment -o yaml` shows the deployment spec. It does not tell you whether metrics-server is collecting data. The correct command is `kubectl top pods` — if it returns `error: Metrics API not available`, metrics-server is not running and that is why HPA shows `<unknown>`.

---

## Six Partials — What Was Missing

| Q | What I answered | What was missing |
|---|---|---|
| Q1 | Image/container distinction ✓, exit code 0 ✓ | Exit code 137 not 138 (wrong, not partial — counted as net 0) |
| Q12 | apply = create-or-update, create = fails-if-exists | "When does it matter": CI/CD pipelines that `apply` the same manifest on every deploy |
| Q24 | EBS Volumes ✓, Load Balancers ✓ | VPC orphan check (not Security Groups) |
| Q27 | WHY --dry-run is non-negotiable ✓ | HOW: the `run()` wrapper pattern from deploy.sh |
| Q30 | Three correct files listed ✓ | WHY each: .terraform/ = 100MB binaries; tfstate = secrets + IDs; tfvars = actual credential values |
| Q2 | Security benefit ✓ | "Save volume" repeats the forbidden answer but security credit still applies |

---

## Strongest Topics (no misses)

Docker · K8s core (Pod/Deployment/Service/probes/rollback) · K8s advanced (Ingress/ConfigMap/Secret/HPA concept) · K8s project (DNS, apply order) · Helm · EKS · Bash scripting · IaC split (Terraform vs Ansible) · Networking (IGW/NAT)

## Weakest Topics (missed or partial)

- **Compose down -v** — critical operational detail
- **HPA diagnostic command** — first command when metrics unknown
- **Terraform .gitignore reasons** — listed files, missed the why
- **--dry-run implementation pattern** — knows the value, not the code pattern
