# Memory Index — ProOps2026

**Last updated:** 2026-05-20 | **Audit score:** 22/32 | **Quiz score:** 20/30

Load this file first. Pick the row(s) relevant to the current task, then load those files.

Status key: ✅ PASS (2/2) · ⚠️ NEEDS WORK (1/2) · ❌ GAP (0/2) · — not in audit rubric

---

## Knowledge Files

| File | Covers | Day-20 | Status |
|---|---|---|---|
| [software-architecture.md](software-architecture.md) | Five architecture patterns (monolith → service mesh): pipeline complexity, scaling model, observability requirements, rollback strategy per pattern | 1/2 | ⚠️ NEEDS WORK — generic only, no RAG chatbot architecture |
| [git.md](git.md) | Branch naming (IRD-001), conventional commits, clone/add/commit/push/pull/branch full flag reference, rebase vs merge, conflict resolution, revert vs reset, DevOps artifact workflows | 2/2 | ✅ PASS |
| [networking-basics.md](networking-basics.md) | DNS resolution chain, 10 essential ports, stateful firewall rules (DROP vs REJECT), TLS handshake + cert errors, L3–L4 connectivity debug checklist | 0/2 | ❌ GAP — container networking (Docker bridge, K8s CoreDNS) entirely missing |
| [linux-basics.md](linux-basics.md) | Filesystem hierarchy (/etc /var /tmp /proc /home /usr/bin), permission model (chmod/chown), user/group management, process management (ps/top/kill), systemd service lifecycle, package management (apt/dnf) | 1/2 | ⚠️ NEEDS WORK — 5 sections present but commands are generic reference, not session-specific |
| [cloud-concepts.md](cloud-concepts.md) | Virtualization stack (physical→hypervisor→VM→container), VM vs container isolation, IaaS/PaaS/SaaS shared responsibility, AZ/region HA design, cloud cost mechanics | 1/2 | ⚠️ NEEDS WORK — all AZ examples use us-east-1, actual region (ap-northeast-2) not documented |
| [aws.md](aws.md) | EC2 lifecycle + key pairs + EIP, S3 operations + bucket policy vs IAM policy, VPC architecture (IGW/NAT/SG), IAM roles vs users + instance profile + IMDS flow, AWS CLI patterns | 0/2 | ❌ GAP — all resource IDs are placeholders; real IDs live in aws-lab-day06.md only |
| [aws-lab-day06.md](aws-lab-day06.md) | Real Day 06 lab artifacts: VPC `vpc-09c073830f75e7a64` (ap-northeast-2), 3 EC2s, EIP, NAT Gateway, S3 buckets `tin-tt-public-assets` + `tin-tt-private-assets`, S3 self-lockout gotcha | — | — reference only |
| [docker.md](docker.md) | Image/container model, Dockerfile rules + layer cache order, Compose structure + networking + volumes + debug decision tree, Day 09 stack overlay with real service hostnames (kafka:9092 milvus:19530 redis:6379) and 3 real Compose mistakes | 2/2 | ✅ PASS |
| [orchestration.md](orchestration.md) | Five orchestration problems, Compose vs Swarm vs K8s comparison table, real Swarm lab observation (1–2s recovery after docker kill), why Kubernetes next | 2/2 | ✅ PASS |
| [kubernetes-core.md](kubernetes-core.md) | Pod/Deployment/Service relationship, liveness vs readiness probes with reasoning, 5-step diagnostic workflow, status-to-command lookup table, minimal manifests | 1/2 | ⚠️ NEEDS WORK — diagnostic table is generic, not linked to real kafka/qna-agent CrashLoopBackOff |
| [kubernetes-advanced.md](kubernetes-advanced.md) | Ingress (host/path routing), ConfigMap (envFrom vs valueFrom), Secret (base64 ≠ encryption — memorize this), HPA (minReplicas/maxReplicas/averageUtilization), Cluster Autoscaler, advanced diagnostic table | 1/2 | ⚠️ NEEDS WORK — HPA section has no real observed scale event |
| [kubernetes-project.md](kubernetes-project.md) | RAG chatbot K8s service map (11 services with real names/ports/images), ConfigMap+Secret contents per service, in-cluster DNS pattern, 7-wave apply order, 11 real failures with root cause + fix | 2/2 | ✅ PASS — most specific file in the set |
| [helm-basics.md](helm-basics.md) | Chart/Release/Repository (non-circular definitions), 8-step install workflow, five operations (install/upgrade/rollback/list/uninstall), values override precedence, service name lookup, failure modes, project charts table (`my-redis` → LangGraph checkpoint) | 2/2 | ✅ PASS |
| [eks-practice.md](eks-practice.md) | Full EKS lifecycle on ap-northeast-2 (account 905418181527, cluster `project-tin-lab`): cluster.yaml, kubectl connect, ECR image URL pattern, cost stack (~$0.14/hr), 7-item skip-list, 5 real errors + fixes, delete + orphan sweep sequence | 2/2 | ✅ PASS |
| [bash-scripting.md](bash-scripting.md) | Six bash production patterns: `set -euo pipefail`, input validation, conditionals (`[[ ]]` table), functions (local scope, separate assign), stdout/stderr/redirect, PATH hygiene for cron; shellcheck integration | 2/2 | ✅ PASS |
| [iac-basics.md](iac-basics.md) | Terraform vs Ansible two-tool rule, core Terraform commands, state file rules (S3 backend), Ansible concepts (modules/handlers/idempotency), decision table, 5 real Day 19 errors | 1/2 | ⚠️ NEEDS WORK — actual `terraform plan`/`apply`/`destroy` output not preserved |

---

## Scripts (audited, not in memory/)

| File | Covers | Day-20 | Status |
|---|---|---|---|
| [scripts/deploy.sh](../scripts/deploy.sh) | 4-phase deploy (git pull → docker build → docker push → kubectl rollout): `run()` dry-run wrapper, `.last-deploy` idempotency check, structured phase logging, preflight EC2 + health checks | 2/2 | ✅ PASS |
| [scripts/monitor-logs.sh](../scripts/monitor-logs.sh) | Cron-safe log monitor: `tail -F` (rotation-safe), ERROR grep with `--line-buffered`, sha256 dedup with TTL pruning, alert-to-file with Slack webhook stub | 2/2 | ✅ PASS |

---

## Meta / Tracking Files

| File | Purpose |
|---|---|
| [gap-analysis.md](gap-analysis.md) | Remediation backlog — which file is weak, what to add, target fix day |
| [day-20-audit.md](day-20-audit.md) | Full Day 20 audit: per-file evidence check, scores (22/32), weakest-3 remediation plan |
| [day-20-quiz-score.md](day-20-quiz-score.md) | Day 20 quiz results: 20/30, per-question breakdown, three confident-wrong analysis |

---

## Load Guide

| Task | Load these files |
|---|---|
| Docker / Compose debugging | docker.md |
| K8s deploy or debug | kubernetes-core.md + kubernetes-project.md |
| K8s advanced objects (Ingress/HPA/Secret) | kubernetes-advanced.md |
| Helm install or upgrade | helm-basics.md |
| EKS cluster work | eks-practice.md + aws.md |
| AWS infrastructure (VPC/SG/IAM) | aws.md + aws-lab-day06.md |
| Bash script or cron job | bash-scripting.md |
| Terraform + Ansible | iac-basics.md |
| Architecture design decision | software-architecture.md |
| Network debug (ping/nc/dig/TLS) | networking-basics.md |
| Git workflow or conflict | git.md |
| What gaps remain | gap-analysis.md |
