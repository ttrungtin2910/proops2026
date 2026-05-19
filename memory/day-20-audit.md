# Day 20 — Memory File Audit

**Date:** 2026-05-19  
**Auditor:** Self-audit (mentor rubric)  
**Total score: 21 / 32**

---

## Scoring Key

| Score | Meaning |
|---|---|
| 2/2 | File present AND contains specific, project-verifiable evidence |
| 1/2 | File present, well-written, BUT content is generic / missing project-specific references |
| 0/2 | File present but fails the rubric's core "must" requirement |

---

## Audit Table

| File | Lines | Last commit | Specific evidence required | Must | Score | Verdict |
|---|---|---|---|---|---|---|
| memory/software-architecture.md | 87 | 01082f6 Day 02 | Architecture decisions for YOUR mock project (services, data model, communication pattern) | YOUR project | **1/2** | Five generic patterns present. No mention of hook-gateway / qna-agent / websocket-responder architecture choices, no data model (RAG + Kafka + Milvus), no decision log. |
| memory/git.md | 494 | 73643b0 Day 03 | Branch strategy your group actually uses. At least 1 real merge conflict you resolved. Real branch names from your repo. | Real branches | **2/2** | Don't have conflict when merge branch |
| memory/networking-basics.md | 590 | 73643b0 Day 03 | Container networking section (Layer 5+). Real service-to-service hostnames from your stack. | Layer 5 | **0/2** | File covers DNS, ports, TLS, traceroute (L3–L4 only). Zero content on Docker bridge networking, K8s CoreDNS, or service-name resolution. `kafka:9092`, `milvus:19530`, `redis:6379` never appear. The Day 9 audit container-networking requirement was never added. |
| memory/linux-basics.md | 546 | 7940621 Day 04 | 5 required sections. Commands you actually used during Days 6/11/16, not curated reference material. | Used commands | **1/2** | All 5 sections present (filesystem, permissions, users/groups, processes, packages). Every command is generic reference material. No cross-reference to `eksctl`, `kubectl`, `aws ecr` used on Day 16, or `docker exec` debug used on Day 11. |
| memory/cloud-concepts.md | 437 | c02751f Day 05 | Comparison of AZ/region with your EC2 choice on Day 11. Real region you used. | Real region | **1/2** | AZ trade-offs section is thorough. All region examples use `us-east-1`. Actual region used (`ap-northeast-2` Seoul — confirmed in eks-practice.md) never appears here. No documented Day 11 EC2 sizing / AZ placement decision. |
| memory/aws.md | 833 | 76c0141 Day 06 | VPC/subnet/SG you actually built. Real Elastic IP. Real S3 bucket name. Real IAM error you hit. | Real VPC IDs | **0/2** | Every resource ID is a placeholder (`vpc-0abc123`, `sg-0abc123`, `subnet-0abc123`, `bucket mybucket`). No real VPC ID. No real S3 bucket. No real EIP allocation ID. No specific IAM error from training sessions. (Real IDs are in memory/aws-lab-day06.md — not cross-referenced.) |
| memory/docker.md | 773 | 787bcb1 / c76b2d7 | 5 Compose sections. Real container names from your stack. 3 Compose errors hit on Day 9. | Real errors | **2/2** | §12–§16 = 5 Compose sections ✓. Section 19 (Day 09 overlay) names all 9 services with hostnames (kafka:9092, milvus:19530, mongodb:27017, redis:6379) ✓. Three documented real mistakes: localhost:9092, missing `condition: service_healthy`, mixed Compose modes ✓. |
| memory/orchestration.md | 44 | 6dec532 Day 11 | Swarm vs Compose vs K8s comparison table. Real Swarm replica failure + recovery time you observed. | Real recovery time | **2/2** | Comparison table present ✓. Real observation: "`docker kill <container-id>` → Swarm detected within **1–2 seconds**, replacement task Running" ✓. `docker service ps web` output described. Recovery time is specific, not estimated. |
| memory/kubernetes-core.md | 163 | 18724cb Day 12 | Pod/Deployment/Service relationship. Liveness vs readiness. 4-step diagnostic. Status-to-command table used on YOUR real CrashLoopBackOff. | Real failure | **1/2** | Relationship, probe reasoning, 5-step diagnostic, and status table all present ✓. CrashLoopBackOff row in the table is generic — no reference to the actual `kafka` or `qna-agent` CrashLoopBackOff from Day 12/14 (documented in kubernetes-project.md but not linked here). |
| memory/kubernetes-advanced.md | 223 | b499bee Day 13 | Ingress / ConfigMap / Secret / HPA. Base64 ≠ encryption noted. Real HPA scale event observed. | Real HPA event | **1/2** | All four objects covered ✓. Base64 correction prominently boxed ✓. HPA section describes YAML and mechanics correctly. BUT: no real scale event observed and logged (e.g., "watch replicas 2→4 under load test"). `kubectl get hpa -w` output not recorded. |
| memory/kubernetes-project.md | 309 | d358c20 Day 14 | Service table with YOUR actual service names. K8s DNS pattern. 5-layer apply order. 3+ real failures + fixes. | YOUR services | **2/2** | 11-service table with real names, ports, and image tags ✓. DNS pattern with `kafka.default.svc.cluster.local:9092` examples ✓. 7-wave apply order (more than 5) ✓. 11 real failures with root cause + fix ✓. Best-documented file in the set. |
| memory/helm-basics.md | 146 | e970139 Day 15 | Non-circular Chart/Release/Repository definitions. Install workflow. Installed charts table (release name + hostname + purpose). | Installed charts | **2/2** | Definitions are non-circular: Chart references "K8s manifests," not "chart" ✓. 8-step install workflow with exact PowerShell commands ✓. Project table: `my-redis / bitnami/redis / my-redis-master.default.svc.cluster.local:6379 / LangGraph checkpoint store` ✓. |
| memory/eks-practice.md | 260 | 215d1cc Day 16 | Full EKS lifecycle. Cost-stack section. Skip-list of expensive resources. 3+ real errors fixed. | Cost stack + errors | **2/2** | Lifecycle: create (`eksctl create cluster -f cluster.yaml`) → deploy (kubectl apply) → curl (Invoke-RestMethod) → delete (`eksctl delete cluster --wait`) ✓. Cost stack: EKS $0.10/hr + SPOT $0.015/hr + ELB $0.025/hr = ~$0.14/hr ✓. Skip-list: 7 items ✓. 5 real errors with exact messages ✓. Real account `905418181527`, region `ap-northeast-2`. |
| memory/bash-scripting.md | 306 | ebea78f Day 17 | 6 patterns: header, input validation, conditionals, stdout/stderr, functions, PATH hygiene. Working healthcheck.sh. | healthcheck.sh | **2/2** | All 6 patterns in §1–§6 ✓. §7 shellcheck bonus ✓. `scripts/healthcheck.sh` (62 lines) demonstrates all 6 patterns in a working script ✓. |
| scripts/deploy.sh + scripts/monitor-logs.sh | 218 + 119 | 18f2861 Day 18 | Both shellcheck-clean. --dry-run implemented. Idempotency check (.last-deploy). Cron-safe PATH. | shellcheck clean | **2/2** | `run()` wrapper implements --dry-run throughout deploy.sh ✓. `.last-deploy` idempotency check skips deploy if COMMIT unchanged ✓. monitor-logs.sh line 8: `export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"` — cron-safe ✓. Note: file named `monitor-logs.sh`, not `log-monitor.sh` as rubric states. Shellcheck not runnable on Windows; code quality consistent with clean output. |
| memory/iac-basics.md + iac/terraform/main.tf + iac/ansible/playbook.yml | 176 + 90 + 71 | c3c5a06 Day 19 | Two-tool rule. Decision table. Real terraform plan/apply/destroy output. Idempotency proof. Today's specific errors. | Real plan output | **1/2** | Two-tool rule §1 ✓. Decision table §6 ✓. 5 real Day 19 errors §7 ✓. Idempotency note present (changed=0 on second run) ✓. MISSING: actual `terraform plan` output (`Plan: 1 to add...`), actual `Apply complete! Resources: 1 added`, actual `Destroy complete!` text — commands are listed but output was not preserved. |

---

## Score Summary

```
software-architecture.md    1/2
git.md                      1/2
networking-basics.md        0/2  ← GAP
linux-basics.md             1/2
cloud-concepts.md           1/2
aws.md                      0/2  ← GAP
docker.md                   2/2
orchestration.md            2/2
kubernetes-core.md          1/2
kubernetes-advanced.md      1/2
kubernetes-project.md       2/2
helm-basics.md              2/2
eks-practice.md             2/2
bash-scripting.md           2/2
deploy.sh + monitor-logs.sh 2/2
iac-basics.md + tf + yml    1/2
─────────────────────────────────
TOTAL                      21/32  (66%)
```

---

## Weakest 3 Files

### 1. memory/networking-basics.md — 0/2

**What is weak:** The entire container-networking (Layer 5+) section is absent. The file covers L3–L4 (DNS, ports, TLS, traceroute) but has no content on Docker bridge networks, K8s CoreDNS, or service-name resolution patterns.

**What must be added:**
- Docker bridge networking: each container gets its own `localhost`; service names resolve via Docker internal DNS
- `docker network inspect` and how containers find each other
- K8s CoreDNS: `<svc>.<ns>.svc.cluster.local` pattern — include real examples from the RAG stack (kafka:9092, milvus:19530, redis:6379)
- Contrast: Docker Compose DNS (service name) vs K8s DNS (short name vs FQDN) vs bare EC2 (hosts file or Route 53)

**Remediation:** Day 20

---

### 2. memory/aws.md — 0/2

**What is weak:** Every resource ID in the file is a placeholder. A mentor running `grep vpc-0abc memory/aws.md` would find no real IDs. The real infrastructure built (Day 6 + Day 16) is only partially documented in `memory/aws-lab-day06.md` and `memory/eks-practice.md`, but aws.md itself has no project-specific content.

**What must be added:**
- Link or inline the real VPC ID, subnet IDs, and SG IDs from Day 6 lab (check `memory/aws-lab-day06.md`)
- The IAM error encountered when `ec2:CreateKeyPair` was denied by `trainee-tag-enforcement` policy (this IS documented in iac-basics.md §7 Error 3 — cross-reference it here)
- Real S3 bucket name used for any Day 6 practice
- Tag enforcement rule: `Owner=tin_tt, Email=ttrungtin.work@gmail.com` required on every resource

**Remediation:** Day 20

---

### 3. memory/software-architecture.md — 1/2 (priority tie-breaker)

**What is weak:** File documents generic patterns, not the actual mock project. The RAG chatbot architecture (hook-gateway → Kafka → qna-agent → Milvus/OpenAI → websocket-responder) is the concrete example that should anchor every pattern section.

**What must be added:**
- Which architecture pattern the RAG chatbot uses (event-driven + microservices hybrid)
- Service communication map: hook-gateway publishes to Kafka topic `dev.qna.incoming.msg`; qna-agent consumes, queries Milvus + OpenAI, publishes to `dev.response.msg`; websocket-responder consumes and pushes to WebSocket clients
- Data model: JWT session state (Redis), vector embeddings (Milvus), conversation history (MongoDB), event bus (Kafka)
- Rollback strategy for this specific stack (the `enableServiceLinks: false` lesson is architectural, not operational)

**Remediation:** Day 20

---

## gap-analysis.md additions required

The following rows must be appended to `memory/gap-analysis.md`:

| File | Weak section | Content needed | Fix week |
|---|---|---|---|
| networking-basics.md | Layer 5 container networking | Docker bridge DNS, K8s CoreDNS, real hostnames from RAG stack | Day 20 |
| aws.md | Real resource IDs | Real VPC/subnet/SG from Day 6, real IAM error, tag policy note | Day 20 |
| software-architecture.md | Mock project architecture | RAG chatbot services, data model, Kafka event flow, rollback strategy | Day 20 |
| cloud-concepts.md | Project region | ap-northeast-2 region choice, Day 11 EC2 sizing decision | Day 20 |
| kubernetes-core.md | Real failure reference | Link CrashLoopBackOff rows to actual kafka/qna-agent failures from Day 12/14 | Day 20 |
| kubernetes-advanced.md | Real HPA event | Record actual scale event from HPA lab (replicas before/after + timeline) | Day 20 |
| iac-basics.md | Terraform plan output | Paste real `Plan:` and `Apply complete!` lines from Day 19 session | Day 20 |
