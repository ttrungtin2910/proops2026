# HPA Lab — Horizontal Pod Autoscaler End-to-End

> Tất cả lệnh chạy trong **PowerShell**.
> metrics-server phải đang chạy — xem Bước 0.

---

## Bước 0 — Kiểm tra prerequisites

```powershell
# metrics-server phải Available = True
kubectl get apiservice v1beta1.metrics.k8s.io
# Nếu False: xem phần Troubleshooting bên dưới

# Xác nhận kubectl top hoạt động
kubectl top nodes
```

**Nếu metrics-server chưa bật:**
```powershell
minikube addons enable metrics-server

# Nếu vẫn MissingEndpoints sau 60s — patch TLS:
kubectl patch deployment metrics-server -n kube-system --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# Chờ Pod restart rồi kiểm tra lại
kubectl get apiservice v1beta1.metrics.k8s.io
```

---

## Bước 1 — Triển khai Deployment và Service

```powershell
# Chạy từ thư mục k8s/hpa/
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-web-deployment.yaml

# Xác nhận Pod Running và có READY 1/1
kubectl get pods -n hpa-lab

# Xác nhận Service có Endpoints (không phải <none>)
kubectl get endpoints -n hpa-lab
```

**Kết quả tốt:**
```
NAME    READY   STATUS    RESTARTS
web-xxx 1/1     Running   0

NAME      ENDPOINTS
web-svc   10.244.x.x:80
```

**Tại sao Deployment cần `resources.requests.cpu`:**
- HPA tính: `desiredReplicas = ceil(currentReplicas × currentCPU / targetCPU)`
- Không có `requests.cpu` → không có baseline → HPA báo `unknown` → không scale

---

## Bước 2 — Tạo HPA

```powershell
kubectl apply -f 02-hpa.yaml

# Xem trạng thái HPA
kubectl get hpa -n hpa-lab
```

**Kết quả tốt (sau ~30 giây):**
```
NAME      REFERENCE        TARGETS   MINPODS   MAXPODS   REPLICAS
web-hpa   Deployment/web   0%/50%    1         5         1
```

> `TARGETS = 0%/50%` nghĩa là: CPU hiện tại 0%, threshold 50%

**Nếu TARGETS vẫn `<unknown>/50%` sau 60 giây:**
```powershell
kubectl describe hpa web-hpa -n hpa-lab
# Tìm dòng: "failed to get cpu utilization" → metrics-server chưa sẵn sàng
# Hoặc:     "missing request for cpu"        → Deployment thiếu resources.requests.cpu
```

---

## Bước 3 — Quan sát trạng thái ban đầu

```powershell
# Mở 2 terminal song song:

# Terminal 1 — watch HPA realtime
kubectl get hpa -n hpa-lab -w

# Terminal 2 — watch Pods realtime
kubectl get pods -n hpa-lab -w
```

Ghi nhận: 1 Pod đang chạy, CPU ~0%.

---

## Bước 4 — Tạo load để trigger scale-up

```powershell
# Terminal 3 — bật load generator
kubectl apply -f 03-load-generator.yaml

# Xác nhận load generator đang gửi request
kubectl logs -n hpa-lab load-generator -f
# Phải thấy: "Load generator started — sending requests to web-svc"
```

**Chờ ~30-60 giây**, quan sát Terminal 1 và Terminal 2:

```
# Terminal 1 — HPA tăng target:
NAME      REFERENCE        TARGETS    REPLICAS
web-hpa   Deployment/web   0%/50%     1
web-hpa   Deployment/web   45%/50%    1
web-hpa   Deployment/web   87%/50%    1      ← vượt 50%
web-hpa   Deployment/web   87%/50%    2      ← scale-up!
web-hpa   Deployment/web   62%/50%    3      ← scale-up tiếp

# Terminal 2 — Pods mới xuất hiện:
web-abc   0/1   Pending   0
web-abc   0/1   ContainerCreating
web-abc   1/1   Running   0
```

**Công thức HPA:**
```
desiredReplicas = ceil(1 × 87% / 50%) = ceil(1.74) = 2
desiredReplicas = ceil(2 × 62% / 50%) = ceil(2.48) = 3
```

---

## Bước 5 — Tắt load và quan sát scale-down

```powershell
# Xóa load generator
kubectl delete -f 03-load-generator.yaml

# Quan sát HPA scale-down
kubectl get hpa -n hpa-lab -w
```

**Scale-down chậm hơn scale-up** (theo thiết kế):
```
NAME      REFERENCE        TARGETS   REPLICAS
web-hpa   Deployment/web   0%/50%    3
web-hpa   Deployment/web   0%/50%    3      ← chờ stabilizationWindow (60s trong lab)
web-hpa   Deployment/web   0%/50%    2      ← giảm 1 Pod
web-hpa   Deployment/web   0%/50%    1      ← về minimum
```

> **Tại sao scale-down chậm?** Tránh "flapping" — load tăng/giảm đột ngột sẽ liên tục scale up/down tốn tài nguyên và gây traffic drop. `stabilizationWindowSeconds` = thời gian HPA phải thấy CPU thấp LIÊN TỤC trước khi scale-down.

---

## Bước 6 — Xem chi tiết sự kiện HPA

```powershell
kubectl describe hpa web-hpa -n hpa-lab
```

**Tìm phần Events:**
```
Events:
  SuccessfulRescale  "New size: 2; reason: cpu resource utilization above target"
  SuccessfulRescale  "New size: 3; reason: cpu resource utilization above target"
  SuccessfulRescale  "New size: 1; reason: All metrics below target"
```

```powershell
# Xem metrics CPU theo thời gian thực của từng Pod
kubectl top pods -n hpa-lab
```

---

## Dọn dẹp

```powershell
kubectl delete namespace hpa-lab
```

---

## Checklist tự kiểm tra

- [ ] Bước 0: `kubectl top nodes` trả về CPU/Memory (metrics-server OK)
- [ ] Bước 1: `kubectl get endpoints -n hpa-lab` có IP (không phải `<none>`)
- [ ] Bước 2: HPA TARGETS hiển thị `0%/50%` (không phải `<unknown>`)
- [ ] Bước 4: HPA tự tăng REPLICAS khi CPU > 50%
- [ ] Bước 4: Hiểu công thức `ceil(currentReplicas × currentCPU / targetCPU)`
- [ ] Bước 5: Scale-down chậm hơn scale-up — hiểu lý do `stabilizationWindow`
- [ ] Bước 6: Đọc được Events trong `kubectl describe hpa`

---

## Troubleshooting

| Triệu chứng | Lệnh kiểm tra | Nguyên nhân / Fix |
|---|---|---|
| `TARGETS = <unknown>` | `kubectl describe hpa web-hpa -n hpa-lab` | metrics-server chưa ready, hoặc thiếu `resources.requests.cpu` |
| HPA không scale dù CPU cao | `kubectl get hpa -n hpa-lab` | `REPLICAS` đã bằng `maxReplicas` (5) |
| load-generator Pod `Error` | `kubectl logs -n hpa-lab load-generator` | web-svc chưa có Endpoints |
| `kubectl top pods` lỗi | `kubectl get apiservice v1beta1.metrics.k8s.io` | metrics-server chưa `AVAILABLE=True` |
| Scale-down không xảy ra | chờ thêm 60-90 giây | `stabilizationWindowSeconds=60` phải trôi qua |
