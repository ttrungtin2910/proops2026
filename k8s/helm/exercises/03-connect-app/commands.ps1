# ============================================================
# Bài 3 — Kết nối qna-agent với Redis Helm service
# ============================================================
# Trước khi chạy bài này: Bài 2 phải hoàn thành (Redis đang Running)

# ── BƯỚC 1: Xác nhận tên Service Redis ───────────────────────
Write-Host "=== TÊN SERVICE REDIS (ghi lại dòng này) ===" -ForegroundColor Cyan
kubectl get svc -n default | Select-String "redis"

# Output mong đợi:
#   my-redis-master     ClusterIP   10.x.x.x   6379/TCP
#   my-redis-replicas   ClusterIP   10.x.x.x   6379/TCP
#   my-redis-headless   ClusterIP   None        6379/TCP
#
# Hostname qna-agent dùng: my-redis-master (trong cùng namespace)

# ── BƯỚC 2: Xem REDIS_URL hiện tại trong ConfigMap ───────────
Write-Host "`n=== REDIS_URL HIỆN TẠI ===" -ForegroundColor Cyan
kubectl get configmap qna-agent-cm -n default `
  -o jsonpath='{.data.REDIS_URL}'
# Output cũ: redis://redis:6379/0   ← hostname Docker Compose

# ── BƯỚC 3: Apply ConfigMap đã cập nhật ──────────────────────
Write-Host "`n=== APPLY CONFIGMAP MỚI ===" -ForegroundColor Cyan
kubectl apply -f d:\14-AIOps_TinTT33\day-14\k8s\configmaps\qna-agent-cm.yaml

# Xác nhận giá trị mới
kubectl get configmap qna-agent-cm -n default `
  -o jsonpath='{.data.REDIS_URL}'
# Output mới: redis://my-redis-master:6379/0   ← Helm Service name

# ── BƯỚC 4: Force Deployment pick up ConfigMap mới ───────────
Write-Host "`n=== ROLLOUT RESTART ===" -ForegroundColor Cyan
kubectl rollout restart deployment qna-agent -n default

# Theo dõi
kubectl rollout status deployment qna-agent -n default --timeout=120s

# ── BƯỚC 5: Xác nhận env var trong Pod mới ───────────────────
Write-Host "`n=== XÁC NHẬN ENV VAR TRONG POD ===" -ForegroundColor Cyan
$POD = kubectl get pod -l app=qna-agent -n default `
  -o jsonpath='{.items[0].metadata.name}'
Write-Host "Pod name: $POD"

kubectl exec -n default $POD -- env | Select-String "REDIS"
# Phải thấy: REDIS_URL=redis://my-redis-master:6379/0

# ── BƯỚC 6: Test DNS resolve từ trong Pod ────────────────────
Write-Host "`n=== TEST DNS RESOLVE ===" -ForegroundColor Cyan
kubectl exec -n default $POD -- python -c "import socket; print(socket.gethostbyname('my-redis-master'))"
# Phải resolve ra IP của Service

# ── BƯỚC 7: Test TCP kết nối ─────────────────────────────────
Write-Host "`n=== TEST TCP PORT 6379 ===" -ForegroundColor Cyan
kubectl exec -n default $POD -- python -c "import socket,sys; s=socket.socket(); s.settimeout(3); s.connect(('my-redis-master',6379)); print('TCP OK'); s.close()"
# Output: Connection to my-redis-master 6379 port succeeded!

# ── BƯỚC 8: Test Redis PING từ trong app Pod ─────────────────
Write-Host "`n=== TEST REDIS PING ===" -ForegroundColor Cyan

# Lấy password từ K8s Secret ra biến PowerShell
$REDIS_PASS = [System.Text.Encoding]::UTF8.GetString(
  [System.Convert]::FromBase64String(
    (kubectl get secret redis-auth-secret -n default -o jsonpath="{.data.redis-password}")
  )
)

# PowerShell expand $REDIS_PASS trước khi gửi vào container
kubectl exec -n default $POD -- python -c "
import redis
r = redis.from_url('redis://:$REDIS_PASS@my-redis-master:6379/0')
print(r.ping())
"
# Kết quả: True
# Kết quả: True  (tương đương PONG — redis-cli không có trong Python slim image)

# ── BƯỚC 9: Test LangGraph checkpoint (Python) ───────────────
Write-Host "`n=== TEST PYTHON REDIS CONNECTION ===" -ForegroundColor Cyan
# $REDIS_PASS đã được lấy ở block trên — PowerShell expand trước khi gửi vào container
kubectl exec -n default $POD -- python -c "
import redis
url = 'redis://:$REDIS_PASS@my-redis-master:6379/0'
print(f'REDIS_URL = {url}')
r = redis.from_url(url)
r.set('helm-connection-test', 'ok-day15')
val = r.get('helm-connection-test').decode()
print(f'Redis value = {val}')
r.delete('helm-connection-test')
print('Connection test PASSED')
"

# ── CHECKPOINT ───────────────────────────────────────────────
Write-Host "`n=== CHECKPOINT ===" -ForegroundColor Yellow
Write-Host "✓ REDIS_URL trong Pod phải là: redis://my-redis-master:6379/0"
Write-Host "✓ redis-cli ping phải trả về: PONG"
Write-Host "✓ Python connection test phải in: Connection test PASSED"
