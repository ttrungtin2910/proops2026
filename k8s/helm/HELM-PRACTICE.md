# Helm Practice — RAG Multi-Agent Chatbot (Day 14)

> Thực hành từng bước với Redis trên Kubernetes.
> Chạy tất cả lệnh trong PowerShell từ thư mục `day-14\k8s\helm\`.

---

## Cấu trúc thư mục

```
k8s/helm/
├── HELM-PRACTICE.md              ← file này
├── my-redis-values.yaml          ← values production-ready (dùng xuyên suốt)
├── exercises/
│   ├── 01-repo-inspect/
│   │   └── commands.ps1          ← bài 1: thêm repo, inspect chart
│   ├── 02-install/
│   │   ├── redis-auth-secret.yaml   ← K8s Secret cho Redis AUTH
│   │   └── commands.ps1          ← bài 2: tạo Secret, cài Redis
│   ├── 03-connect-app/
│   │   └── commands.ps1          ← bài 3: cập nhật ConfigMap, test kết nối
│   ├── 04-upgrade-rollback/
│   │   ├── values-v2.yaml        ← values cho upgrade (memory tăng)
│   │   ├── values-bad.yaml       ← values xấu để giả lập fail
│   │   └── commands.ps1          ← bài 4: upgrade → fail → rollback
│   └── 05-helm-create/
│       └── commands.ps1          ← bài 5: tạo chart từ đầu, khám phá cấu trúc
└── solutions/
    └── expected-outputs.md       ← output mong đợi của từng lệnh
```

---

## Bài 1 — Thêm repo và inspect chart

**Mục tiêu:** Biết cách tìm chart, đọc values trước khi cài.

```powershell
# Chạy file bài 1
d:\14-AIOps_TinTT33\day-14\k8s\helm\exercises\01-repo-inspect\commands.ps1
```

Hoặc chạy từng lệnh trong `exercises/01-repo-inspect/commands.ps1`.

**Checkpoint:** Sau bài này bạn phải trả lời được:
- Chart version của `bitnami/redis` là gì?
- `maxmemory-policy` mặc định của chart là gì?
- Key nào trong values.yaml kiểm soát số replica?

---

## Bài 2 — Tạo Secret và cài Redis

**Mục tiêu:** Cài Redis đúng cách — credential trong K8s Secret, không hardcode.

```powershell
# Bước 1: Tạo K8s Secret trước
kubectl apply -f exercises\02-install\redis-auth-secret.yaml

# Bước 2: Cài Redis với values file
helm install my-redis bitnami/redis `
  -f my-redis-values.yaml `
  -n default

# Bước 3: Theo dõi Pod khởi động
kubectl get pods -w -n default
```

**Checkpoint:** Sau bài này bạn phải thấy:
- `my-redis-master-0` STATUS = `Running`
- `helm list` hiển thị STATUS = `deployed`, REVISION = `1`

---

## Bài 3 — Kết nối qna-agent với Redis

**Mục tiêu:** Đổi hostname từ Docker Compose sang Helm Service name.

```powershell
# Đọc hướng dẫn chi tiết
cat exercises\03-connect-app\commands.ps1
```

**Checkpoint:**
```powershell
# Lệnh này phải trả về PONG
kubectl exec -it $(kubectl get pod -l app=qna-agent -o name) -- `
  redis-cli -h my-redis-master ping
```

---

## Bài 4 — Upgrade và Rollback

**Mục tiêu:** Thực hành vòng lặp upgrade → verify → fail → rollback.

```powershell
cat exercises\04-upgrade-rollback\commands.ps1
```

**Thứ tự thực hành:**
1. Upgrade với `values-v2.yaml` (memory tăng) → verify revision 2
2. Upgrade với `values-bad.yaml` (image sai) → thấy `STATUS: failed`
3. Rollback về revision 2 → verify revision 4 xuất hiện

**Checkpoint:** `helm history my-redis` phải hiển thị 4 revision.

---

## Bài 5 — Tạo chart từ đầu

**Mục tiêu:** Hiểu cấu trúc chart bằng cách tự tạo.

```powershell
cat exercises\05-helm-create\commands.ps1
```

**Checkpoint:** Chạy được `helm template . --debug` và đọc output YAML.

---

## Lệnh kiểm tra nhanh (dùng bất cứ lúc nào)

```powershell
# Trạng thái tổng quan
helm list -n default
kubectl get all -n default | Select-String "redis|qna"

# Lịch sử release
helm history my-redis -n default

# Secret Helm trong etcd
kubectl get secrets -n default | Select-String "helm"

# Log Redis master
kubectl logs statefulset/my-redis-master -n default --tail=20

# Test kết nối nhanh
kubectl run redis-test --rm -it --restart=Never `
  --image=redis:7 -n default `
  -- redis-cli -h my-redis-master ping
```

---

## Dọn dẹp sau khi thực hành

```powershell
helm uninstall my-redis -n default
kubectl delete secret redis-auth-secret -n default
kubectl delete pod redis-test -n default --ignore-not-found
```
