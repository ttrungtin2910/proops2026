---
name: EKS Practice — Day 16
description: Full EKS workflow from pre-flight to teardown — commands, patterns, real errors+fixes, minikube vs EKS diff
type: project
originSessionId: e3c2248c-fef1-4e70-9d4b-14a78ca98380
---
## Account / Region

| Key | Value |
|-----|-------|
| Account ID | 905418181527 |
| IAM user | tin_tt |
| Region | ap-northeast-2 (Seoul) |
| Cluster name | project-tin-lab |

---

## 1. Pre-flight

```powershell
aws sts get-caller-identity                                      # verify personal account
eksctl version                                                   # must be installed
aws ec2 describe-availability-zones --region ap-northeast-2     # verify region reachable
eksctl get cluster --region ap-northeast-2                      # check for stale clusters
```

---

## 2. cluster.yaml (full)

Location: `D:\14-AIOps_TinTT33\proops2026\k8s\cluster.yaml`

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: project-tin-lab
  region: ap-northeast-2
  version: "1.32"
  tags:
    Owner: tin_tt
    Email: ttrungtin.work@gmail.com
availabilityZones:
  - ap-northeast-2a
  - ap-northeast-2b
vpc:
  nat:
    gateway: Disable        # saves ~$30/mo
managedNodeGroups:
  - name: ng-spot
    instanceTypes: [t3.medium]
    spot: true
    desiredCapacity: 1
    minSize: 1
    maxSize: 1
    privateNetworking: false  # public subnet — no NAT needed
    iam:
      attachPolicyARNs:
        - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
        - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
        - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
# NO aws-ebs-csi-driver addon — requires OIDC, crashes without it
```

```powershell
# Create
eksctl create cluster -f "D:\14-AIOps_TinTT33\proops2026\k8s\cluster.yaml"

# If AlreadyExists error → stale CF stack, delete first:
aws cloudformation update-termination-protection --stack-name eksctl-project-tin-lab-cluster --no-enable-termination-protection --region ap-northeast-2
aws cloudformation delete-stack --stack-name eksctl-project-tin-lab-cluster --region ap-northeast-2
eksctl delete cluster --name project-tin-lab --region ap-northeast-2 --wait
# Then retry create
```

---

## 3. Connect kubectl

```powershell
aws eks update-kubeconfig --region ap-northeast-2 --name project-tin-lab
kubectl config current-context   # arn:aws:eks:ap-northeast-2:905418181527:cluster/project-tin-lab
kubectl get nodes -o wide        # expect INTERNAL-IP + EXTERNAL-IP (public subnet)
kubectl get pods -n kube-system  # aws-node, coredns, kube-proxy → Running
```

---

## 4. ECR image URL pattern

```
905418181527.dkr.ecr.ap-northeast-2.amazonaws.com/<repo-name>:<tag>
```

```powershell
# Login (expires 12h)
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 905418181527.dkr.ecr.ap-northeast-2.amazonaws.com

# Build (always explicit platform — Windows x86_64 is safe, M1 Mac is not)
docker build --platform linux/amd64 -t <name>:v1 .

# Tag + Push
docker tag <name>:v1 905418181527.dkr.ecr.ap-northeast-2.amazonaws.com/<repo>:v1
docker push 905418181527.dkr.ecr.ap-northeast-2.amazonaws.com/<repo>:v1
```

### Project repos

| Repo | Image in Deployment |
|------|-------------------|
| project-tin-hook-gateway | `905418181527.dkr.ecr.ap-northeast-2.amazonaws.com/project-tin-hook-gateway:v1` |
| project-tin-qna-agent | `905418181527.dkr.ecr.ap-northeast-2.amazonaws.com/project-tin-qna-agent:v1` |
| project-tin-websocket-responder | `905418181527.dkr.ecr.ap-northeast-2.amazonaws.com/project-tin-websocket-responder:v1` |
| project-tin-frontend | `905418181527.dkr.ecr.ap-northeast-2.amazonaws.com/project-tin-frontend:v1` |

No `imagePullSecrets` needed — node IAM role has `AmazonEC2ContainerRegistryReadOnly`.

---

## 5. Cost stack (ap-northeast-2, t3.medium SPOT)

| Resource | Rate | Notes |
|----------|------|-------|
| EKS control plane | ~$0.10/hr | Always on while cluster exists |
| t3.medium SPOT | ~$0.015/hr | ~70% cheaper than on-demand |
| Classic ELB | ~$0.025/hr | Only when LoadBalancer Service exists |
| NAT Gateway | $0 | Disabled in cluster.yaml |
| **Total** | **~$0.14/hr** | ~$1.12/8hr lab session |

**Rule: Delete cluster after each lab. Set phone alarm at start.**

---

## 6. Skip-list (training cluster)

| Feature | Why skip |
|---------|----------|
| NAT Gateway | $30/mo, not needed with public subnets |
| `aws-ebs-csi-driver` addon | Requires OIDC — crashes without it; not needed unless using PVCs |
| OIDC provider | Extra setup, not needed for basic lab |
| Private subnets | Require NAT Gateway to work |
| Multi-AZ nodegroup | Cost — 1 node is enough for dev |
| CloudWatch logging | Cost + noise for lab |
| Replica nodes (Redis) | `replicaCount: 0` in Helm values |

---

## 7. Real errors + fixes (today)

### CF stack AlreadyExists
```
Error: AlreadyExistsException: Stack [eksctl-project-tin-lab-cluster] already exists
```
**Fix:** Disable termination protection → delete stack → delete EKS cluster → retry create.

### Nodegroup CREATE_FAILED (old cluster)
```
NodeCreationFailure: Instances failed to join the kubernetes cluster
```
**Root cause:** NAT Gateway `nat-046fd70f043e6e452` deleted — nodes in private subnet had no route to EKS API.  
**Fix:** Create new cluster with `privateNetworking: false` (public subnet) + `nat.gateway: Disable`.

### aws-ebs-csi-driver addon timeout
```
timed out waiting for addon "aws-ebs-csi-driver" to become active
```
**Root cause:** No OIDC provider → addon can't get IAM permissions → stuck CREATING.  
**Fix:** `aws eks delete-addon --cluster-name project-tin-lab --addon-name aws-ebs-csi-driver`. Remove from cluster.yaml. Use `persistence.enabled: false` in Helm values.

### MongoDB readiness probe failing (0/1 Running)
```
Readiness probe failed: command timed out: "mongosh --eval ..." timed out after 1s
```
**Root cause:** Default `timeoutSeconds: 1` — mongosh (Node.js) takes >1s to start.  
**Fix:** Add `timeoutSeconds: 10` to readiness probe.

### POST /webchat → 400 Bad Request
**Root cause:** Sent `{"message": "..."}` but API expects `{"text": "..."}` (field defined in `WebChatRequest.Text`).  
**Fix:** Use `{"text": "..."}`.

### PowerShell curl syntax
**Root cause:** `curl` in PowerShell is alias for `Invoke-WebRequest`, not curl.exe.  
**Fix:** Use `Invoke-WebRequest -Uri "..." -UseBasicParsing` or install curl.exe separately.

---

## 8. Apply order (infra + app)

```powershell
# Infra — dependency order
kubectl apply -f k8s/infra/zookeeper.yaml
kubectl apply -f k8s/infra/kafka.yaml
kubectl apply -f k8s/infra/mongodb.yaml
kubectl apply -f k8s/infra/etcd.yaml
kubectl apply -f k8s/infra/minio.yaml
kubectl apply -f k8s/infra/milvus.yaml
# SKIP infra/redis.yaml — using Helm my-redis instead

# Helm Redis
kubectl create secret generic redis-auth-secret --from-literal=redis-password=<password>
helm install my-redis bitnami/redis -f k8s/helm/my-redis-values.yaml -n default

# App
kubectl apply -f k8s/configmaps/
kubectl create secret generic hook-gateway-secret --from-literal=JWT_SECRET=<value>
kubectl create secret generic websocket-responder-secret --from-literal=JWT_SECRET=<value>
kubectl create secret generic qna-agent-secret --from-literal=OPENAI_API_KEY=<value>
kubectl apply -f k8s/deployments/
kubectl apply -f k8s/services/

# Migration (run once after milvus is Ready)
kubectl exec <qna-agent-pod> -c qna-agent -- sh -c "cd /app && PYTHONPATH=. python -m app.cli.migrate"
```

---

## 9. Delete sequence

```powershell
# Step 1 — Helm first
helm uninstall my-redis -n default

# Step 2 — Cluster (blocks until done)
eksctl delete cluster --name project-tin-lab --region ap-northeast-2 --wait

# Step 3 — Verify cluster gone
eksctl get cluster --region ap-northeast-2           # must be empty
aws eks list-clusters --region ap-northeast-2        # must return {"clusters": []}

# Step 4 — Orphan sweep
# EC2 Volumes (EBS not released)
aws ec2 describe-volumes --region ap-northeast-2 --filters "Name=tag:kubernetes.io/cluster/project-tin-lab,Values=owned" --query "Volumes[].VolumeId"

# EC2 Load Balancers (Service type:LoadBalancer not cleaned up)
aws elb describe-load-balancers --region ap-northeast-2 --query "LoadBalancerDescriptions[?contains(LoadBalancerName,'a50c7fe')].LoadBalancerName"

# VPC orphan
aws ec2 describe-vpcs --region ap-northeast-2 --filters "Name=tag:alpha.eksctl.io/cluster-name,Values=project-tin-lab" --query "Vpcs[].VpcId"

# Step 5 — ECR (optional, cheap but dev-only images)
# aws ecr delete-repository --repository-name project-tin-hook-gateway --force --region ap-northeast-2
```

---

## 10. minikube vs EKS diff

| Item | minikube | EKS |
|------|----------|-----|
| Image source | Local docker daemon (no push needed) | ECR — must `docker push` first |
| Image URL | `myapp:v1` | `905418181527.dkr.ecr.ap-northeast-2.amazonaws.com/myapp:v1` |
| `imagePullSecrets` | Not needed | Not needed (node IAM role handles it) |
| Service `LoadBalancer` | `minikube tunnel` required | Auto-provisions Classic ELB (~5 min) |
| `EXTERNAL-IP` | `127.0.0.1` (tunnel) | Real ELB hostname |
| Persistence (PVC) | Buggy default StorageClass | `gp2` works — but needs EBS CSI driver + OIDC |
| Secret source | `kubectl create secret` | Same — External Secrets Operator for prod |
| Node architecture | Host arch (may vary) | Always `linux/amd64` — build with `--platform linux/amd64` |
| Startup time | ~1 min | 15–20 min |
| Cost | Free | ~$0.14/hr |
| Auth | None | IAM → `aws eks get-token` → bearer token |
