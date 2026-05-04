# ============================================================
# Bài 4 — Upgrade → Verify → Fail → Rollback
# ============================================================
# Trước khi chạy: helm list phải hiện STATUS=deployed, REVISION=1

Set-Location d:\14-AIOps_TinTT33\day-14\k8s\helm\exercises\04-upgrade-rollback

# ══════════════════════════════════════════════════════════════
# PHẦN A — Upgrade thành công (revision 2)
# ══════════════════════════════════════════════════════════════

Write-Host "=== PHẦN A: UPGRADE THÀNH CÔNG ===" -ForegroundColor Green

# A1. Xem trạng thái trước
helm list -n default
helm history my-redis -n default

# A2. Diff: xem sẽ thay đổi gì (nếu có plugin helm-diff)
# helm diff upgrade my-redis bitnami/redis -f values-v2.yaml -n default

# A3. Chạy upgrade
helm upgrade my-redis bitnami/redis `
  -f values-v2.yaml `
  -n default

# A4. Theo dõi rollout
kubectl rollout status statefulset/my-redis-master -n default --timeout=90s

# A5. Xác nhận revision 2
Write-Host "`n--- Helm history sau upgrade ---" -ForegroundColor Cyan
helm history my-redis -n default

# A6. Xác nhận memory thay đổi trong StatefulSet
Write-Host "`n--- Resource requests trong StatefulSet ---" -ForegroundColor Cyan
kubectl get statefulset my-redis-master -n default `
  -o jsonpath='{.spec.template.spec.containers[0].resources}' | ConvertFrom-Json

# Phải thấy: requests.memory = 256Mi (không còn 128Mi)

# A7. Xác nhận label mới
Write-Host "`n--- Pod labels ---" -ForegroundColor Cyan
kubectl get pod my-redis-master-0 -n default --show-labels

# ══════════════════════════════════════════════════════════════
# PHẦN B — Giả lập upgrade THẤT BẠI (revision 3 = failed)
# ══════════════════════════════════════════════════════════════

Write-Host "`n=== PHẦN B: GIẢ LẬP UPGRADE THẤT BẠI ===" -ForegroundColor Red
Write-Host "File values-bad.yaml dùng image tag không tồn tại." -ForegroundColor Yellow
Write-Host "Helm KHÔNG tự rollback. Pod cũ vẫn chạy." -ForegroundColor Yellow
Read-Host "Nhấn Enter để tiếp tục..."

# B1. Upgrade với image tag sai
helm upgrade my-redis bitnami/redis `
  -f values-bad.yaml `
  -n default

# B2. Theo dõi Pod mới fail (Ctrl+C sau 30 giây)
Write-Host "`n--- Pod status (Ctrl+C sau 30 giây) ---" -ForegroundColor Cyan
kubectl get pods -n default -w

# B3. Xem lý do fail
Write-Host "`n--- Events trên Pod mới ---" -ForegroundColor Cyan
kubectl describe pod -l app.kubernetes.io/name=redis -n default | `
  Select-String -Context 0,3 "Events|ImagePull|Failed"

# B4. Xác nhận helm history STATUS = failed
Write-Host "`n--- Helm history ---" -ForegroundColor Cyan
helm history my-redis -n default
# REVISION 3 phải có STATUS: failed

# B5. Xác nhận helm list
helm list -n default
# STATUS: failed   ← đây là trạng thái nguy hiểm trong production

# ══════════════════════════════════════════════════════════════
# PHẦN C — Rollback về revision 2
# ══════════════════════════════════════════════════════════════

Write-Host "`n=== PHẦN C: ROLLBACK VỀ REVISION 2 ===" -ForegroundColor Green

# C1. Rollback
helm rollback my-redis 2 -n default

# C2. Theo dõi
kubectl rollout status statefulset/my-redis-master -n default --timeout=90s

# C3. Xem history — rollback tạo revision MỚI (revision 4)
Write-Host "`n--- Helm history sau rollback ---" -ForegroundColor Cyan
helm history my-redis -n default

# Phải thấy:
#   REVISION 1 → superseded  → install complete
#   REVISION 2 → superseded  → upgrade complete
#   REVISION 3 → superseded  → upgrade failed
#   REVISION 4 → deployed    → rollback to 2

# C4. Xác nhận Pod đang chạy đúng image
Write-Host "`n--- Image đang chạy ---" -ForegroundColor Cyan
kubectl get pod my-redis-master-0 -n default `
  -o jsonpath='{.spec.containers[0].image}'
# Phải là redis:7.2.x (không phải 99.99.99)

# C5. Xác nhận Secrets trong etcd — tất cả revision vẫn còn
Write-Host "`n--- Helm Secrets trong etcd ---" -ForegroundColor Cyan
kubectl get secrets -n default | Select-String "helm"
# Phải thấy v1, v2, v3, v4

# C6. Test Redis vẫn hoạt động sau rollback
Write-Host "`n--- Test Redis PING ---" -ForegroundColor Cyan
kubectl run redis-verify --rm -it --restart=Never `
  --image=redis:7 -n default `
  -- redis-cli -h my-redis-master ping
# Kết quả: PONG

# ── CHECKPOINT ───────────────────────────────────────────────
Write-Host "`n=== CHECKPOINT CUỐI BÀI ===" -ForegroundColor Yellow
Write-Host "✓ helm history phải hiện 4 revision"
Write-Host "✓ REVISION 4 STATUS = deployed"
Write-Host "✓ REVISION 3 STATUS = superseded (không phải failed nữa)"
Write-Host "✓ Redis PING = PONG"
Write-Host ""
Write-Host "Câu hỏi để suy nghĩ:"
Write-Host "  - Tại sao rollback tạo revision 4 thay vì xóa revision 3?"
Write-Host "  - kubectl rollout undo có làm được điều tương tự không?"
Write-Host "  - Khi nào nên rollback, khi nào nên fix-forward?"
