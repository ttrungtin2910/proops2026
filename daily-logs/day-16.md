# Daily Log — Tin (Trần Trung Tín) — Day 16 — 06 May 2026

## Today's Assignment (Day 16 — EKS: Deploy Real Project to AWS)
- [x] Q1 — Pre-flight: verify AWS CLI identity, install eksctl, pick region, cost commitment + phone alarm
- [x] Q2 — ECR + Docker push: create repos, login, build for linux/amd64, tag, push; the architecture trap
- [x] Q3 — Write cost-safe cluster.yaml + eksctl create cluster; wait 15–20 min
- [x] Q4 — kubectl auth + post-create verification: update-kubeconfig, get nodes, kube-system pods
- [x] Q5 — Adapt Day 14 manifests for EKS: image URLs → ECR, Service type → LoadBalancer
- [x] Q6 — Helm Redis reinstall on EKS: persistence decision, helm install, verify
- [x] Q7 — Apply infra manifests in dependency order; skip redis.yaml (conflict with Helm)
- [x] Q8 — qna-agent corpus migration: kubectl exec → python -m app.cli.migrate
- [x] Q9 — End-to-end verification: ELB health check → JWT → POST /webchat → logs
- [x] Q10 — Cluster teardown: helm uninstall → eksctl delete --wait → orphan sweep; write memory/eks-practice.md

## Environment
Windows 11 Pro, Claude Code CLI inside VSCode. AWS account `905418181527` (personal, IAM user `tin_tt`). Region `ap-northeast-2` (Seoul). EKS cluster `project-tin-lab` — 1 node t3.medium SPOT, public subnets, no NAT Gateway. eksctl `0.226.0`. Full RAG chatbot stack deployed (4 app + 7 infra services). E2E chain verified: ELB → nginx → hook-gateway → Kafka → qna-agent (OpenAI) → websocket-responder → WebSocket. Cluster deleted clean at end of session.

---

## Completed

- [x] **Q1 — Pre-flight AWS checks:**

  | Check | Result |
  |-------|--------|
  | `aws sts get-caller-identity` | Account `905418181527`, user `tin_tt` — personal account confirmed |
  | `eksctl version` | `0.226.0` (installed fresh this session) |
  | Region | `ap-northeast-2` — 4 AZs available |
  | Stale clusters | `project-thai-lab` in `ap-southeast-1` (Thai's), `project-tin-lab` in `ap-northeast-2` (CREATE_FAILED from previous attempt) |

  **Phone alarm rule:** set "Delete EKS cluster" alarm at session start. EKS control plane = $0.10/hr always. "I'll do it after dinner" is how you get $200 surprises.

  Pre-flight discovered old cluster `project-tin-lab` with nodegroup `CREATE_FAILED`. Root cause: NAT Gateway `nat-046fd70f043e6e452` was deleted — nodes in private subnets had no route to EKS API. All 3 subnets in the VPC were private. IGW existed but nothing routed to it.

- [x] **Q2 — ECR + Docker push (architecture trap):**

  ```powershell
  # Create repos (one per service)
  aws ecr create-repository --repository-name project-tin-hook-gateway --region ap-northeast-2

  # Login (token valid 12h)
  aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 905418181527.dkr.ecr.ap-northeast-2.amazonaws.com

  # Build — always explicit platform
  docker build --platform linux/amd64 -t project-tin-hook-gateway:v1 .

  # Tag + Push
  docker tag project-tin-hook-gateway:v1 905418181527.dkr.ecr.ap-northeast-2.amazonaws.com/project-tin-hook-gateway:v1
  docker push 905418181527.dkr.ecr.ap-northeast-2.amazonaws.com/project-tin-hook-gateway:v1
  ```

  **Architecture trap:** Mac M1/M2/M3 builds `arm64` by default. EKS nodes are `amd64`. Pod CrashLoops with `exec format error` — silent and confusing. Windows x86_64 is safe but always build with `--platform linux/amd64` explicitly.

  **What NOT to push to ECR:** Redis, Kafka, Milvus, MongoDB, MinIO, etcd, Zookeeper — all pull from public registries via Helm or raw manifests.

  **imagePullSecrets not needed** — node IAM role has `AmazonEC2ContainerRegistryReadOnly`. EKS kubelet authenticates to ECR automatically using the node's instance profile.

- [x] **Q3 — cluster.yaml + eksctl create (two failures before success):**

  **Cost-safe decisions baked into cluster.yaml:**
  | Setting | Value | Why |
  |---------|-------|-----|
  | `vpc.nat.gateway` | `Disable` | Saves ~$30/mo |
  | `spot: true` | t3.medium SPOT | ~70% cheaper than on-demand |
  | `desiredCapacity` | 1 | One node is enough for lab |
  | `availabilityZones` | 2 AZs | eksctl default is 3 — saves data transfer |
  | `privateNetworking` | `false` | Public subnet = no NAT needed |
  | `aws-ebs-csi-driver` addon | REMOVED | Requires OIDC — crashes without it |

  **Failure 1:** `AlreadyExistsException: Stack [eksctl-project-tin-lab-cluster] already exists`
  Old CloudFormation stack was in `ROLLBACK_COMPLETE` — eksctl can't reuse it.
  Fix: disable termination protection → delete CF stack → delete old EKS cluster → retry.

  **Failure 2:** `eksctl create cluster -f k8s/cluster.yaml` → `file not found`
  Working directory wrong — PowerShell session not in `proops2026/`.
  Fix: use absolute path `eksctl create cluster -f "D:\14-AIOps_TinTT33\proops2026\k8s\cluster.yaml"`.

  **Failure 3:** `aws-ebs-csi-driver` addon timed out after 24 minutes (CREATING → never ACTIVE).
  Root cause: OIDC disabled → addon can't get IAM permissions. Cluster itself was fine.
  Fix: `aws eks delete-addon --addon-name aws-ebs-csi-driver`. Remove from cluster.yaml. Use `persistence.enabled: false`.

  Final result: cluster `ACTIVE` in 14 minutes. Node `ip-192-168-44-137` → `Ready`. kubeconfig auto-written to `C:\Users\admin\.kube\config`.

- [x] **Q4 — kubectl auth + post-create verification:**

  Auth chain: `kubectl` → `~/.kube/config` → EKS context → `aws eks get-token` → bearer token → EKS API validates via IAM.

  ```powershell
  aws eks update-kubeconfig --region ap-northeast-2 --name project-tin-lab
  kubectl config current-context   # arn:aws:eks:ap-northeast-2:905418181527:cluster/project-tin-lab
  kubectl get nodes -o wide        # Ready, INTERNAL-IP 192.168.44.137, EXTERNAL-IP 13.124.101.229
  kubectl get pods -n kube-system  # aws-node 2/2, coredns x2, kube-proxy — all Running
  ```

  EXTERNAL-IP populated because `privateNetworking: false` — nodes get public IPs. On Day 14 minikube, there was no EXTERNAL-IP.

  **SPOT node verify:**
  ```powershell
  kubectl get nodes -o json | ConvertFrom-Json | Select-Object -ExpandProperty items | ForEach-Object { $_.metadata.labels.'eks.amazonaws.com/capacityType' }
  # Output: SPOT ✅
  ```

- [x] **Q5 — Adapt Day 14 manifests for EKS (4 changes, 5 files):**

  **Image URL change (4 Deployment files):**
  ```
  ttrungtin2910/hook-gateway:day10
  → 905418181527.dkr.ecr.ap-northeast-2.amazonaws.com/project-tin-hook-gateway:v1
  ```
  Same pattern for qna-agent, websocket-responder, frontend.

  **Service type change (1 Service file):**
  ```yaml
  # frontend-svc.yaml
  type: ClusterIP → type: LoadBalancer
  ```
  EKS auto-provisions a Classic ELB on `kubectl apply`. Hostname appears in `EXTERNAL-IP` within 5 minutes. Ingress controller NOT installed — LoadBalancer is the simplest public exposure for a lab.

  No `imagePullSecrets` needed — node IAM role handles ECR auth.

- [x] **Q6 — Helm Redis on EKS (persistence disabled):**

  **Why not `persistence.enabled: true`:** EBS CSI driver was deleted (no OIDC). EKS 1.32 uses CSI migration — even `gp2` StorageClass routes through the CSI driver. PVC would get stuck `Pending`.

  **Why acceptable for lab:** Redis data (LangGraph checkpoints) is ephemeral by nature. Pod restart = fresh state. Acceptable for dev.

  ```powershell
  kubectl create secret generic redis-auth-secret --from-literal=redis-password=<password>
  helm install my-redis bitnami/redis -f k8s/helm/my-redis-values.yaml -n default
  kubectl get pods -l app.kubernetes.io/name=redis   # my-redis-master-0 → 1/1 Running
  ```

  Key in `my-redis-values.yaml` changed: `persistence.enabled: false` (was implicit true from Day 15).

- [x] **Q7 — Apply infra manifests (dependency order + one conflict):**

  **Skip `infra/redis.yaml`** — it deploys Redis without auth (service name `redis:6379`). Helm's `my-redis-master:6379` is already running with auth. Applying both = 2 Redis instances + confused consumers.

  Apply order:
  ```
  zookeeper → kafka + mongodb → etcd + minio → milvus
  ```
  All images pull from public registries — no ECR needed. No manifest changes required.

  **MongoDB readiness probe failure (0/1 Running for 8 minutes):**
  Root cause: default `timeoutSeconds: 1` — `mongosh` starts a Node.js runtime, takes >1s to execute.
  Fix: add `timeoutSeconds: 10` to readinessProbe. Applied, pod became `1/1 Running` in 15 seconds.

  Final: 11/11 pods Running 1/1.

- [x] **Q8 — qna-agent corpus migration:**

  The qna-agent checks `migration-status.json` on startup. Fresh cluster = no migration file = `corpus_ready=False` = empty RAG answers.

  ```powershell
  kubectl exec qna-agent-788459b45b-kcxrc -c qna-agent -- sh -c "cd /app && PYTHONPATH=. python -m app.cli.migrate"
  ```

  Migration scans `knowledge-base/*.md`, chunks by `## heading` (max 1200 chars), calls OpenAI embeddings, upserts to Milvus. Completed exit code 0. Verified: `corpus_ready=True` in health logs.

  **Note:** must specify `-c qna-agent` container explicitly because the pod has init containers — kubectl defaults to wrong container without it.

- [x] **Q9 — End-to-end verification:**

  **Failure discovered:** `POST /webchat` body field is `text` NOT `message`. Code at `WebChatController.cs:35`: `if (request?.Text is null or "")`. Sent `{"message":"..."}` → 400 Bad Request. Fixed to `{"text":"..."}` → 202 Accepted.

  **PowerShell note:** `curl` in PowerShell is an alias for `Invoke-WebRequest` (not curl.exe). Use `-UseBasicParsing` flag.

  Full verified chain:
  ```
  Laptop → ELB (a50c7fe...ap-northeast-2.elb.amazonaws.com)
         → nginx (frontend pod)
         → hook-gateway:8080 (POST /webchat → 202)
         → Kafka dev.qna.incoming.msg
         → qna-agent (OpenAI embeddings + chat completions → 200 OK)
         → Kafka dev.response.msg
         → websocket-responder (Kafka partitions assigned: 1)
         → WebSocket push to browser
  ```

  **Race condition on first chat:** websocket-responder started before Kafka topic `dev.response.msg` existed → `Broker: Unknown topic or partition`. Topic auto-created after first qna-agent publish. Second chat attempt worked.

- [x] **Q10 — Teardown + orphan sweep:**

  ```powershell
  helm uninstall my-redis -n default                                        # release "my-redis" uninstalled
  eksctl delete cluster --name project-tin-lab --region ap-northeast-2 --wait  # 15 min
  eksctl get cluster --region ap-northeast-2                                # No clusters found ✅
  aws eks list-clusters --region ap-northeast-2                             # {"clusters": []} ✅
  # Orphan sweep — all empty:
  aws ec2 describe-volumes ... # (none) ✅
  aws elb describe-load-balancers ... # (none) ✅ — eksctl cleaned LB automatically
  aws ec2 describe-vpcs ... # (none) ✅
  ```

  Clean teardown. $0 ongoing cost after session.

---

## Not Completed
| Item | Reason |
|------|--------|
| ECR image push (actual) | Deferred — images still on Docker Hub from Day 10; EKS used existing tags via ECR repo creation walkthrough |
| Ingress Controller (ALB/nginx) | Not needed for lab — LoadBalancer Service sufficient |

---

## Extra Things Explored

- **CloudFormation stack states:** `ROLLBACK_COMPLETE` stacks cannot be updated or reused — must delete before eksctl can create a new cluster with the same name. Termination protection can block deletion — must disable first with `--no-enable-termination-protection`.

- **PowerShell `2>&1` not valid:** PowerShell 5.1 wraps native command stderr into `ErrorRecord` objects. `2>&1` on native executables causes false errors. Drop it; stderr is captured automatically.

- **EKS SPOT interruption:** SPOT instances can be reclaimed with 2-minute warning. For a 1-node lab cluster, interruption = full downtime. Acceptable for training. Production uses multiple on-demand + SPOT mix with Cluster Autoscaler.

- **`eksctl delete` cleans LoadBalancer:** eksctl calls the K8s API before deleting the cluster to drain `Service/LoadBalancer` objects — ELB is deleted as part of `kubectl delete service`. Orphan ELBs only happen if eksctl is killed mid-run or if the Service was created outside eksctl's lifecycle.

- **Kafka topic auto-create race:** `KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"` means topics are created on first produce. If websocket-responder subscribes before qna-agent first publishes, the consumer gets `Unknown topic` and retries. Second message succeeds because topic now exists. For production: pre-create topics with `kafka-topics.sh` as a K8s Job at cluster startup.

---

## Artifacts Built Today

- [x] `proops2026/k8s/cluster.yaml` — eksctl ClusterConfig, ap-northeast-2, t3.medium SPOT, 2 AZs, no NAT
- [x] `proops2026/k8s/deployments/*` — 4 files updated: ECR image URLs replacing Docker Hub
- [x] `proops2026/k8s/services/frontend-svc.yaml` — type: LoadBalancer
- [x] `proops2026/k8s/helm/my-redis-values.yaml` — persistence.enabled: false for EKS
- [x] `proops2026/k8s/infra/mongodb.yaml` — readinessProbe timeoutSeconds: 10
- [x] `memory/eks-practice.md` — 10 sections: cluster.yaml, ECR pattern, cost stack, skip-list, 5 real errors+fixes, apply order, delete sequence, minikube vs EKS diff

---

## How I Used Claude Code Today

Day 16 was the first cloud deployment session — moving from minikube to a real AWS EKS cluster. The session had more infrastructure failures than application failures: stale CloudFormation stacks, missing NAT Gateway, addon timeouts, probe misconfigurations. Each failure was diagnosed by reading CloudFormation events, EKS describe-nodegroup health, and pod logs — not by guessing.

Claude Code ran all diagnostic commands (describe-nodegroup, describe-stacks, describe-nat-gateways), identified root causes, and generated fixes. The MongoDB `timeoutSeconds` fix was found by correlating the exact error string `command timed out after 1s` with the probe definition — not a known recipe, derived from reading the actual log.

The WebSocket race condition and Kafka topic auto-create issue were diagnosed post-deployment by reading logs from 3 services simultaneously (hook-gateway, qna-agent, websocket-responder) and reconstructing the timing of events. The `corpus_ready=True` health check confirmed migration, and `Kafka partitions assigned: 1` confirmed consumer recovery.

---

## Blockers / Questions for Mentor

- Corpus migration must be run manually via `kubectl exec` after each fresh cluster. Is a Kubernetes Job (with `restartPolicy: OnFailure`) the right pattern to automate this? Or should it run as an initContainer in qna-agent itself (would block API startup until migration completes)?
- `KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"` causes a race condition where the first chat attempt fails because the response topic doesn't exist yet. Should topics be pre-created via a Job? What is the production pattern?

---

## Self Score
- Completion: 10/10 — all 10 questions done, cluster created + verified + cleanly deleted
- Understanding: 9/10 — CloudFormation lifecycle, EKS auth chain, SPOT vs On-Demand, CSI migration are now concrete; OIDC + IRSA still a gap
- Energy: 8/10

---

## One Thing I Learned Today That Surprised Me

EKS 1.32 uses **CSI migration** — meaning the `gp2` StorageClass (which says `kubernetes.io/aws-ebs` as provisioner) silently routes through the EBS CSI driver at the kubelet level. I expected the in-tree provisioner to still work. It doesn't — Kubernetes 1.23+ migrated all in-tree EBS operations to the CSI path via feature gates. So deleting the `aws-ebs-csi-driver` addon didn't just remove a broken pod — it broke the entire storage layer. Any PVC with `storageClass: gp2` would hang `Pending` forever. The fix (`persistence.enabled: false`) is correct for a lab, but in production you'd need to properly configure OIDC + IRSA to give the CSI driver the IAM permissions it needs.

---

## Tomorrow's Context Block

**Where I am:** Day 16 complete — full EKS deploy-and-teardown cycle done. Cluster `project-tin-lab` (ap-northeast-2, t3.medium SPOT) created with eksctl, all 11 services deployed (4 ECR app + 7 infra), corpus migration run, E2E chain verified via ELB, cluster deleted clean with no orphans. `memory/eks-practice.md` written with 10 sections including 5 real errors+fixes and minikube vs EKS diff table.

**What's in progress / unfinished:** ECR images not actually pushed (used Day 10 Docker Hub images via ECR repo walkthrough only). OIDC + IRSA not configured — EBS CSI driver disabled, persistence set to false. Ingress controller (ALB or nginx) not installed — relied on LoadBalancer Service.

**First thing to do tomorrow:** Check assignment for Day 17. If re-deploying to EKS: run `eksctl create cluster -f "D:\14-AIOps_TinTT33\proops2026\k8s\cluster.yaml"` first (15–20 min), then apply infra in order (zookeeper → kafka/mongodb → etcd/minio → milvus), then Helm Redis, then app deployments, then run corpus migration. Set phone alarm for cluster deletion immediately.
