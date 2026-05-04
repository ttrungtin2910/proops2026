# ============================================================
# Bài 5 — Tạo Helm chart từ đầu, khám phá cấu trúc
# ============================================================
# Mục tiêu: Hiểu _helpers.tpl, named templates, dot-notation,
#           helm template --debug dry-run

Set-Location d:\14-AIOps_TinTT33\day-14\k8s\helm\exercises\05-helm-create

# ── BƯỚC 1: Tạo chart scaffold ───────────────────────────────
Write-Host "=== TẠO CHART ===" -ForegroundColor Cyan
helm create myapp

# Xem cấu trúc được tạo ra
Write-Host "`n--- Cấu trúc thư mục ---" -ForegroundColor Cyan
Get-ChildItem -Recurse myapp | Select-Object FullName

# ── BƯỚC 2: Đọc từng file quan trọng ─────────────────────────

Write-Host "`n--- Chart.yaml ---" -ForegroundColor Cyan
Get-Content myapp\Chart.yaml

Write-Host "`n--- values.yaml (30 dòng đầu) ---" -ForegroundColor Cyan
Get-Content myapp\values.yaml | Select-Object -First 30

Write-Host "`n--- _helpers.tpl ---" -ForegroundColor Cyan
Get-Content myapp\templates\_helpers.tpl

# Câu hỏi: Tại sao file bắt đầu bằng dấu _?
# Câu hỏi: {{- define "myapp.fullname" -}} kết thúc ở đâu?

# ── BƯỚC 3: Trace dot-notation từ values → template ──────────
Write-Host "`n=== TRACE DOT-NOTATION ===" -ForegroundColor Cyan

# Xem image.tag trong values.yaml
Write-Host "--- image.tag trong values.yaml ---"
Get-Content myapp\values.yaml | Select-String "tag"

# Xem {{ .Values.image.tag }} trong deployment.yaml
Write-Host "`n--- .Values.image.tag trong deployment.yaml ---"
Get-Content myapp\templates\deployment.yaml | Select-String "image|tag"

# Giải thích:
#   .Values        = toàn bộ values.yaml
#   .Values.image  = map "image:" trong values.yaml
#   .Values.image.tag = field "tag:" trong map đó

# ── BƯỚC 4: Render với giá trị mặc định ─────────────────────
Write-Host "`n=== HELM TEMPLATE — GIÁ TRỊ MẶC ĐỊNH ===" -ForegroundColor Cyan
Set-Location myapp
helm template . | Select-String -Context 0,2 "image:"

# ── BƯỚC 5: Override image.tag và so sánh ───────────────────
Write-Host "`n=== HELM TEMPLATE — OVERRIDE IMAGE TAG ===" -ForegroundColor Cyan
helm template . --set image.tag=v2.0.0 | Select-String -Context 0,2 "image:"

# So sánh hai output:
#   Default: image: "nginx:latest" (hoặc appVersion)
#   Override: image: "nginx:v2.0.0"

# ── BƯỚC 6: Thử tham chiếu key không tồn tại ─────────────────
Write-Host "`n=== KEY KHÔNG TỒN TẠI ===" -ForegroundColor Cyan

# Thêm tạm một tham chiếu vào deployment.yaml
$content = Get-Content templates\deployment.yaml -Raw
$testLine = '          # test: "{{ .Values.nonExistentKey }}"'
# Xem output khi key không tồn tại (empty string, không báo lỗi)
helm template . --set-string "dummy=1" 2>&1 | Select-String "nonExistent" -Quiet
Write-Host "Key không tồn tại → chuỗi rỗng (không báo lỗi)"
Write-Host "Dùng 'required' để bắt buộc: {{ .Values.key | required 'key là bắt buộc' }}"

# ── BƯỚC 7: Debug mode — xem computed values ─────────────────
Write-Host "`n=== HELM TEMPLATE --DEBUG ===" -ForegroundColor Cyan
helm template . --debug --set image.tag=v2.0.0 2>&1 | Select-Object -First 40

# --debug in ra:
#   USER-SUPPLIED VALUES: những gì bạn --set
#   COMPUTED VALUES: kết quả merge default + override
#   Sau đó là YAML đầy đủ

# ── BƯỚC 8: Validate YAML syntax ────────────────────────────
Write-Host "`n=== VALIDATE YAML ===" -ForegroundColor Cyan
helm lint .
# output: [INFO] Chart.yaml: icon is recommended
# output: 1 chart(s) linted, 0 chart(s) failed

Set-Location ..

# ── BƯỚC 9: Dọn dẹp ─────────────────────────────────────────
Write-Host "`n=== DỌN DẸP ===" -ForegroundColor Cyan
Write-Host "Xóa chart thực hành? (y/n)"
$confirm = Read-Host
if ($confirm -eq 'y') {
  Remove-Item -Recurse -Force myapp
  Write-Host "Đã xóa thư mục myapp/"
}

# ── CHECKPOINT ───────────────────────────────────────────────
Write-Host "`n=== CHECKPOINT CUỐI BÀI ===" -ForegroundColor Yellow
Write-Host "✓ Giải thích được tại sao _helpers.tpl có dấu gạch dưới"
Write-Host "✓ Trace được .Values.image.tag từ values.yaml → deployment.yaml"
Write-Host "✓ Biết rằng key không tồn tại → chuỗi rỗng, không lỗi"
Write-Host "✓ helm template . --debug là bước bắt buộc trước helm install"
