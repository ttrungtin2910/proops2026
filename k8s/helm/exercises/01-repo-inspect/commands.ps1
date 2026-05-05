# ============================================================
# Bài 1 — Thêm Helm repo và inspect chart trước khi cài
# ============================================================
# Chạy từng block một. Đọc output trước khi chạy block tiếp theo.

# ── BƯỚC 1: Thêm bitnami repo ────────────────────────────────
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Câu hỏi: Repo được lưu ở đâu trên máy bạn?
# Gợi ý: helm env | Select-String "REPOSITORY"
helm env | Select-String "REPOSITORY"

# ── BƯỚC 2: Tìm kiếm chart Redis ─────────────────────────────
helm search repo redis

# Đọc output:
#   CHART VERSION  = phiên bản của Helm chart
#   APP VERSION    = phiên bản thật của Redis
# Câu hỏi: Hai số này có giống nhau không? Tại sao?

# ── BƯỚC 3: Xem toàn bộ values (300-600 dòng) ────────────────
# Chạy lần này để hiểu cấu trúc tổng thể
helm show values bitnami/redis | more

# ── BƯỚC 4: Grep những phần quan trọng ───────────────────────

# 4a. Cấu hình AUTH
Write-Host "`n=== AUTH CONFIG ===" -ForegroundColor Cyan
helm show values bitnami/redis | Select-String -Context 0,10 "^auth:"

# 4b. Persistence
Write-Host "`n=== PERSISTENCE CONFIG ===" -ForegroundColor Cyan
helm show values bitnami/redis | Select-String -Context 0,8 "persistence:"

# 4c. Resource limits
Write-Host "`n=== RESOURCES CONFIG ===" -ForegroundColor Cyan
helm show values bitnami/redis | Select-String -Context 0,8 "resources:"

# 4d. maxmemory — key production gotcha
Write-Host "`n=== MAXMEMORY CONFIG ===" -ForegroundColor Cyan
helm show values bitnami/redis | Select-String -Context 0,5 "maxmemory"

# ── BƯỚC 5: Xem Chart.yaml (metadata) ────────────────────────
Write-Host "`n=== CHART METADATA ===" -ForegroundColor Cyan
helm show chart bitnami/redis

# ── BƯỚC 6: Xem README tóm tắt ───────────────────────────────
# helm show readme bitnami/redis | more   # bỏ comment nếu muốn đọc

# ── CHECKPOINT ───────────────────────────────────────────────
# Write-Host "`n=== CHECKPOINT — Trả lời 3 câu hỏi sau ===" -ForegroundColor Yellow
# Write-Host "1. Chart version của bitnami/redis hiện tại là bao nhiêu?"
# Write-Host "2. Số replica mặc định (replica.replicaCount) là bao nhiêu?"
# Write-Host "3. Key nào trong values kiểm soát Redis AUTH password trực tiếp?"
# Write-Host "   (Gợi ý: auth.______ — nhìn output bước 4a)"
