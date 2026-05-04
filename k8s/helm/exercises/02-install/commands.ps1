# ============================================================
# Bài 2 — Tạo Secret và cài Redis bằng Helm
# ============================================================
# Chạy từ thư mục: day-14\k8s\helm\

# ── BƯỚC 1: Dry-run trước khi cài thật ───────────────────────
Write-Host "=== DRY RUN — Xem YAML sẽ được apply ===" -ForegroundColor Cyan
helm template my-redis bitnami/redis `
  -f ..\..\helm\my-redis-values.yaml `
  -n default | more

# Đọc output — tìm những thứ sau:
#   - image tag được dùng là gì?
#   - maxmemory có xuất hiện trong ConfigMap không?
#   - resources.requests.memory là bao nhiêu?

# ── BƯỚC 2: Tạo K8s Secret cho Redis AUTH ────────────────────
Write-Host "`n=== TẠO SECRET ===" -ForegroundColor Cyan
kubectl apply -f redis-auth-secret.yaml

# Xác nhận Secret đã tạo (xem data — sẽ là base64)
kubectl get secret redis-auth-secret -n default -o yaml

# ── BƯỚC 3: Helm install ──────────────────────────────────────
Write-Host "`n=== HELM INSTALL ===" -ForegroundColor Cyan
helm install my-redis bitnami/redis `
  -f ..\..\helm\my-redis-values.yaml `
  -n default

# Output sẽ gồm:
#   NAME, NAMESPACE, STATUS: deployed, REVISION: 1
#   + NOTES.txt — ĐỌC KỸ phần này, nó có hostname và lệnh test

# ── BƯỚC 4: Theo dõi Pod khởi động ───────────────────────────
Write-Host "`n=== THEO DÕI POD (Ctrl+C để dừng) ===" -ForegroundColor Cyan
kubectl get pods -n default -w
# Chờ my-redis-master-0 STATUS = Running, READY = 1/1

# ── BƯỚC 5: Xác nhận tất cả objects ─────────────────────────
Write-Host "`n=== XÁC NHẬN OBJECTS ===" -ForegroundColor Cyan
kubectl get all -n default | Select-String "redis"

# Ghi lại tên Service:
#   my-redis-master    ClusterIP   xxx.xxx.xxx.xxx   6379/TCP
#   ^^^^^^^^^^^^^^^^^
#   Đây là hostname qna-agent sẽ dùng

# ── BƯỚC 6: Xem lịch sử Helm và Secrets trong etcd ──────────
Write-Host "`n=== HELM HISTORY ===" -ForegroundColor Cyan
helm history my-redis -n default

Write-Host "`n=== HELM SECRETS TRONG ETCD ===" -ForegroundColor Cyan
kubectl get secrets -n default | Select-String "helm"

# ── BƯỚC 7: Test kết nối Redis (không cần app) ───────────────
Write-Host "`n=== TEST KẾT NỐI REDIS ===" -ForegroundColor Cyan
$REDIS_PASS = kubectl get secret redis-auth-secret -n default `
  -o jsonpath="{.data.redis-password}"
$REDIS_PASS = [System.Text.Encoding]::UTF8.GetString(
  [System.Convert]::FromBase64String($REDIS_PASS)
)

kubectl run redis-test --rm -it --restart=Never `
  --image=redis:7 -n default `
  -- redis-cli -h my-redis-master -a $REDIS_PASS ping

# Kết quả mong đợi: PONG

# ── CHECKPOINT ───────────────────────────────────────────────
Write-Host "`n=== CHECKPOINT ===" -ForegroundColor Yellow
Write-Host "Kiểm tra: helm list -n default"
helm list -n default
Write-Host ""
Write-Host "✓ STATUS phải là: deployed"
Write-Host "✓ REVISION phải là: 1"
Write-Host "✓ Pod my-redis-master-0 phải ở trạng thái: Running"
