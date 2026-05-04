# Expected Outputs — Helm Practice

> Dùng file này để đối chiếu output thực tế với output mong đợi.
> Nếu output của bạn khác đây, đọc phần "Sai lầm thường gặp".

---

## Bài 1 — Repo & Inspect

### `helm search repo redis`
```
NAME                    CHART VERSION   APP VERSION   DESCRIPTION
bitnami/redis           19.x.x          7.2.x         Redis(R) is an open source...
bitnami/redis-cluster   11.x.x          7.2.x         Redis(R) Cluster is a...
```
*(số version thay đổi theo thời gian)*

### `helm show values bitnami/redis | Select-String "^auth:" -Context 0,8`
```yaml
auth:
  enabled: true
  sentinel: true
  existingSecret: ""
  existingSecretPasswordKey: ""
  password: ""
  usePasswordFiles: false
  usePasswordFileFromSecret: true
```

---

## Bài 2 — Install

### `helm list -n default` (sau install)
```
NAME       NAMESPACE  REVISION  STATUS    CHART          APP VERSION
my-redis   default    1         deployed  redis-19.x.x   7.2.x
```

### `kubectl get all -n default | Select-String "redis"`
```
pod/my-redis-master-0            1/1   Running   0   2m

service/my-redis-headless   ClusterIP   None          6379/TCP
service/my-redis-master     ClusterIP   10.x.x.x      6379/TCP
service/my-redis-replicas   ClusterIP   10.x.x.x      6379/TCP

statefulset.apps/my-redis-master     1/1   2m
statefulset.apps/my-redis-replicas   0/0   2m
```

### `kubectl get secrets -n default | Select-String "helm"`
```
sh.helm.release.v1.my-redis.v1   helm.sh/release.v1   1   2m
```

---

## Bài 4 — Upgrade & Rollback

### `helm history my-redis` (sau toàn bộ bài 4)
```
REVISION  STATUS      DESCRIPTION
1         superseded  install complete
2         superseded  upgrade complete
3         superseded  upgrade failed
4         deployed    rollback to 2
```

### `kubectl get secrets -n default | Select-String "helm"` (sau bài 4)
```
sh.helm.release.v1.my-redis.v1   helm.sh/release.v1   1   90m
sh.helm.release.v1.my-redis.v2   helm.sh/release.v1   1   30m
sh.helm.release.v1.my-redis.v3   helm.sh/release.v1   1   15m
sh.helm.release.v1.my-redis.v4   helm.sh/release.v1   1   5m
```

---

## Bài 5 — Helm Create

### `helm template . | Select-String "image:"`
```yaml
      - image: "nginx:1.21.0"
```

### `helm template . --set image.tag=v2.0.0 | Select-String "image:"`
```yaml
      - image: "nginx:v2.0.0"
```

### `helm lint .`
```
==> Linting .
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

---

## Sai lầm thường gặp

| Triệu chứng | Nguyên nhân | Fix |
|---|---|---|
| `Error: INSTALLATION FAILED: cannot re-use a name that is still in use` | Release `my-redis` đã tồn tại | Dùng `helm upgrade` thay vì `helm install` |
| Pod ở trạng thái `Pending` | PVC không bind được | Thêm `--set master.persistence.enabled=false` |
| `Error: secret "redis-auth-secret" not found` | Chưa tạo Secret trước khi install | Chạy `kubectl apply -f redis-auth-secret.yaml` trước |
| `PONG` không trả về | AUTH fail hoặc sai hostname | Kiểm tra password và hostname bằng `nslookup` |
| `helm rollback` không có revision number | Helm rollback về revision trước đó 1 bước | `helm rollback my-redis` (không cần số) = rollback 1 bước |
