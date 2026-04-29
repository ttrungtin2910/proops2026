# Ingress Lab — Hướng dẫn thực hành (Windows)

> Tất cả lệnh chạy trong **PowerShell** (không phải CMD).
> `kubectl` và `minikube` đã cài sẵn và có trong PATH.

---

## Chuẩn bị

```powershell
# 1. Bật ingress controller trên minikube
minikube addons enable ingress

# 2. Xác nhận controller đang chạy (chờ ~60 giây)
kubectl get pods -n ingress-nginx
# Phải thấy ingress-nginx-controller-xxx  1/1  Running

# 3. Kiểm tra driver (Docker driver cần thêm bước tunnel bên dưới)
minikube profile list
```

> **Docker driver trên Windows — bắt buộc:**
> IP minikube (`192.168.49.x`) không reachable từ Windows host.
> Mở một terminal riêng, chạy as Administrator và giữ terminal đó mở:
> ```powershell
> minikube tunnel
> ```
> Sau đó dùng `127.0.0.1` thay cho `minikube ip` trong tất cả lệnh curl bên dưới.

---

## Phần 1 — Khởi tạo các Services

```powershell
# Chạy từ thư mục k8s/ingress/
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-frontend.yaml
kubectl apply -f 02-api.yaml
kubectl apply -f 03-admin.yaml

# Kiểm tra: tất cả Pods phải Running, Endpoints phải có IP
kubectl get pods -n ingress-lab
kubectl get endpoints -n ingress-lab
```

**Kết quả tốt:**
```
NAME                        READY   STATUS    RESTARTS
frontend-xxx                1/1     Running   0
api-xxx                     1/1     Running   0
admin-xxx                   1/1     Running   0

NAME           ENDPOINTS
admin-svc      10.244.x.x:80
api-svc        10.244.x.x:80,10.244.x.x:80
frontend-svc   10.244.x.x:80,10.244.x.x:80
```

**Kết quả xấu:** `<none>` trong cột ENDPOINTS → label mismatch:
```powershell
kubectl describe svc frontend-svc -n ingress-lab | Select-String "Selector"
kubectl get pods -n ingress-lab --show-labels
# So sánh Selector với Labels — phải khớp nhau
```

---

## Phần 2 — Path-based Routing

```powershell
kubectl apply -f 04-path-ingress.yaml

# Kiểm tra Ingress đã resolve được Services chưa
kubectl describe ingress path-ingress -n ingress-lab
# Tìm dòng Backends: phải có IP trong ngoặc, không phải <error>
```

**Test:**
```powershell
# minikube tunnel đang chạy → dùng 127.0.0.1
# Nếu không dùng tunnel: $MINIKUBE_IP = minikube ip rồi thay 127.0.0.1

# / → FRONTEND
curl.exe -H "Host: app.local" "http://127.0.0.1/"
# Kết quả: <h1>FRONTEND</h1>

# /api → API
curl.exe -H "Host: app.local" "http://127.0.0.1/api"
# Kết quả: {"service": "api", ...}

# /api/users → vẫn hit API vì pathType: Prefix
curl.exe -H "Host: app.local" "http://127.0.0.1/api/users"
# Kết quả: {"service": "api", ...}
```

> **Tại sao `curl.exe` không phải `curl`?**
> Trong PowerShell, `curl` là alias của `Invoke-WebRequest` — syntax khác hoàn toàn.
> `curl.exe` gọi thẳng binary curl.exe (có sẵn từ Windows 10 1803).

---

## Phần 3 — Host-based Routing

> **Lưu ý conflict:** `05-host-ingress.yaml` dùng `frontend.local` (không phải `app.local`)
> vì `app.local + /` đã được định nghĩa trong `path-ingress` ở Phần 2.
> nginx Ingress controller không cho phép hai Ingress dùng cùng `host + path`.

```powershell
kubectl apply -f 05-host-ingress.yaml
kubectl get ingress -n ingress-lab
# Phải thấy cả path-ingress và host-ingress đều có ADDRESS
```

**Test không cần sửa hosts file — dùng `-H` header:**
```powershell
curl.exe -H "Host: frontend.local" "http://127.0.0.1"   # → FRONTEND
curl.exe -H "Host: admin.local"    "http://127.0.0.1"   # → ADMIN PANEL
```

**Hoặc thêm vào hosts file** (PowerShell **as Administrator**):
```powershell
# Nếu dùng minikube tunnel: ip = 127.0.0.1
# Nếu không dùng tunnel: $ip = minikube ip
$ip = "127.0.0.1"

Add-Content C:\Windows\System32\drivers\etc\hosts "$ip  frontend.local"
Add-Content C:\Windows\System32\drivers\etc\hosts "$ip  admin.local"

# Xác nhận
Get-Content C:\Windows\System32\drivers\etc\hosts | Select-String "local"
```

**Test sau khi thêm hosts:**
```powershell
curl.exe http://frontend.local   # → <h1>FRONTEND</h1>
curl.exe http://admin.local      # → <h1>ADMIN PANEL</h1>
```

**Dọn hosts file sau lab** (as Administrator):
```powershell
$hosts = Get-Content C:\Windows\System32\drivers\etc\hosts
$hosts | Where-Object { $_ -notmatch "frontend\.local|admin\.local|app\.local" } |
  Set-Content C:\Windows\System32\drivers\etc\hosts
```

---

## Phần 4 — Debug Lab (3 lỗi phổ biến)

```powershell
kubectl apply -f 06-debug-lab.yaml
kubectl get ingress -n ingress-lab
```

### Scenario A: Typo trong tên Service
```powershell
kubectl describe ingress broken-typo -n ingress-lab
# Tìm dòng: endpoints "api-service" not found
# Fix: sửa service.name: "api-service" → "api-svc" trong 06-debug-lab.yaml
# Sau khi sửa: kubectl apply -f 06-debug-lab.yaml
```

### Scenario B: pathType Exact vs Prefix
```powershell
kubectl get ingress broken-pathtype -n ingress-lab -o yaml | Select-String "pathType"
# Thấy: Exact

# Test để thấy lỗi:
curl.exe -H "Host: app.local" "http://127.0.0.1/api/users"
# Kết quả: 404 (Exact chỉ match "/api", không match "/api/users")

# Fix: đổi pathType: Exact → pathType: Prefix trong 06-debug-lab.yaml
```

### Scenario C: Port sai
```powershell
kubectl describe ingress broken-port -n ingress-lab
# Tìm dòng: Backends: api-svc:80 (<error: ...>)

kubectl get svc api-svc -n ingress-lab
# Thấy: PORT(S) 8080/TCP  ← đây là port đúng cần điền vào Ingress

# Fix: đổi port.number: 80 → 8080 trong 06-debug-lab.yaml
```

---

## Dọn dẹp sau lab

```powershell
kubectl delete namespace ingress-lab
# Xóa namespace sẽ xóa tất cả: Pods, Services, Ingresses, ConfigMaps bên trong
```

---

## Checklist tự kiểm tra

- [ ] Path-based: `/api` route đúng đến api-svc, `/` route đúng đến frontend-svc
- [ ] Path-based: `/api/users` vẫn hit api-svc (Prefix match)
- [ ] Host-based: `frontend.local` và `admin.local` trả về response khác nhau
- [ ] Hiểu tại sao không dùng `app.local` trong `host-ingress` (conflict với `path-ingress`)
- [ ] Debug A: tìm được lỗi typo qua `kubectl describe ingress`
- [ ] Debug B: hiểu tại sao `Exact` bị lỗi với `/api/users`
- [ ] Debug C: tìm đúng port của Service bằng `kubectl get svc`

---

## Troubleshooting nhanh

| Triệu chứng | Lệnh kiểm tra | Nguyên nhân thường gặp |
|---|---|---|
| `connection refused` | `kubectl get pods -n ingress-nginx` | Ingress controller chưa Running |
| `404` từ nginx | `kubectl describe ingress <name> -n ingress-lab` | Ingress chưa apply, hoặc host/path không match |
| `503` từ nginx | `kubectl get endpoints <svc> -n ingress-lab` | Service không có Endpoints (label mismatch) |
| Timeout khi curl | `minikube tunnel` đang chạy chưa? | Docker driver cần tunnel để expose port 80/443 |
| `admission webhook denied` khi apply | `kubectl get ingress -n ingress-lab` | host + path đã tồn tại trong Ingress khác |
