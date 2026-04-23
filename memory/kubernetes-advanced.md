# Kubernetes Advanced

All manifests use `app: web`, namespace `production` — compose directly with `kubernetes-core.md`.

---

## Ingress

**Gap it fills:** NodePort exposes one port per Service (30000–32767). At 10+ services: firewall rules multiply, no TLS centralization, no clean DNS. Ingress consolidates all HTTP/HTTPS traffic through one entry point (port 80/443).

**Prerequisites:**
- Ingress controller Pod must be running (`kubectl get pods -n ingress-nginx`)
- On minikube: `minikube addons enable ingress`

```yaml
# Ingress — routes /api to api-svc, / to web-svc
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 8080
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-svc
            port:
              number: 80
```

**Two routing modes:**
- **Host-based:** different `host:` values → different Services (api.example.com vs admin.example.com)
- **Path-based:** same host, different `path:` values → different Services (/api vs /admin)

---

## ConfigMap

**Gap it fills:** env vars hardcoded in Deployment = one YAML file per environment. 3 environments = 3 near-identical files; a change to Deployment spec must be replicated manually. ConfigMap decouples config from Deployment.

**Prerequisites:** none — ConfigMap is a core API object.

```yaml
# ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
  namespace: production
data:
  DATABASE_HOST: "db.internal"
  LOG_LEVEL: "info"
```

**Two injection methods (add to Deployment container spec):**

```yaml
# (a) envFrom — entire ConfigMap becomes env vars
envFrom:
- configMapRef:
    name: web-config
```

```yaml
# (b) valueFrom — one specific key, can rename
env:
- name: DATABASE_HOST
  valueFrom:
    configMapKeyRef:
      name: web-config
      key: DATABASE_HOST
```

Use `envFrom` for all-or-nothing injection; use `valueFrom` when you need to rename a key or pull from a shared ConfigMap selectively.

---

## Secret

**Gap it fills:** ConfigMap values are plaintext in etcd and visible in `kubectl get cm -o yaml`. Secret is the designated object for sensitive values — it enables RBAC-based access restriction and (optionally) etcd encryption-at-rest.

**Prerequisites:** RBAC enabled (on by default). For real protection: etcd encryption-at-rest configured, or an external secret store (Vault, AWS Secrets Manager, Azure Key Vault via CSI driver).

> **CORRECTION — MEMORIZE THIS:**
> **Secrets are NOT encrypted by default — base64 is encoding, not encryption.**
> Anyone with `kubectl get secret` + `base64 -d` reads the value in one command.
> Access control is enforced by RBAC and (optionally) etcd encryption-at-rest.
> "Encrypted in Kubernetes" is a false claim. It is how real clusters get owned.

```yaml
# Secret — values are base64-encoded (echo -n "value" | base64)
apiVersion: v1
kind: Secret
metadata:
  name: web-secret
  namespace: production
type: Opaque
data:
  DB_PASSWORD: c3VwZXJzZWNyZXQ=   # "supersecret"
```

**Two mount methods:**

```yaml
# (a) env var — simple, but leaks into process listings and crash dumps
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: web-secret
      key: DB_PASSWORD
```

```yaml
# (b) volumeMount — safer: not in process listing, app reads file on demand
volumes:
- name: secret-vol
  secret:
    secretName: web-secret
volumeMounts:
- name: secret-vol
  mountPath: /etc/secrets
  readOnly: true
```

Prefer file mount in production. Env vars appear in `ps aux`, crash dumps, and any tool that dumps the environment.

---

## HPA (Horizontal Pod Autoscaler)

**Gap it fills:** static `replicas: 3` wastes resources at low traffic and drops requests at high traffic. HPA adjusts replica count automatically based on CPU (or custom metrics).

**Prerequisites:**
- `metrics-server` must be running (`kubectl top pods` must work)
- Container must have `resources.requests.cpu` set — HPA formula is `actual_cpu / cpu_request × 100`
- On minikube: `minikube addons enable metrics-server`

```yaml
# HPA — targets Deployment web, scales between 2 and 10 replicas
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

- **`minReplicas`:** floor — Pods never drop below this, even at zero traffic.
- **`maxReplicas`:** ceiling — prevents autoscaler from exhausting quota during abnormal spikes.
- **`averageUtilization: 70`:** scale up when avg CPU across all Pods exceeds 70% of their request; scale down when sustained below threshold.
- **Scale-down cooldown:** 5 minutes default. Pods are killed slower than added — prevents flapping under bursty traffic.

**Watch live:**
```bash
kubectl get hpa -w
# TARGETS shows <unknown>/70% if metrics-server is missing
```

---

## HPA vs Cluster Autoscaler

| | HPA | Cluster Autoscaler |
|---|---|---|
| Scales | Pods (replicas) | Nodes (EC2/VMSS instances) |
| Trigger | CPU / memory metrics | Pending Pods |
| Failure mode | `TARGETS: <unknown>` — metrics-server missing | Pending Pods stay stuck — CA not installed or ASG quota hit |

They are two independent control loops that compose: HPA creates Pods → Pods go Pending (no room) → CA adds a Node → Pods get scheduled.

**Managed names:** EKS = Cluster Autoscaler or Karpenter | AKS = Cluster Autoscaler | GKE = Node Auto-Provisioning.

minikube is single-node — CA has no cloud API to call. Pending Pods on minikube stay Pending.

---

## ConfigMap vs Secret

| | ConfigMap | Secret |
|---|---|---|
| Shape | `data: key: plaintext` | `data: key: base64string` |
| Storage in etcd | Plaintext | base64 (NOT encrypted by default) |
| Access control | Standard RBAC | Standard RBAC (restrict tighter) |
| Leak risk | Low — intended for non-sensitive config | High — base64 decoded in one command by anyone with `kubectl get secret` |

---

## Diagnostic Lookup Table — Advanced Objects

| You see | Check | What you're looking for |
|---------|-------|------------------------|
| Ingress returns 404 | `kubectl describe ingress <name>` → then `kubectl get endpoints <svc>` | Missing Ingress controller; `pathType` wrong; Service has no Endpoints (label mismatch) |
| HPA stuck at `<unknown>/70%` | `kubectl top pods` | metrics-server not running → `minikube addons enable metrics-server` |
| Secret mounted but file empty | `kubectl describe pod <name>` → Events | Secret name typo in `secretName`; wrong `mountPath`; Secret exists in different namespace |
| Pods Pending after HPA scale-up | `kubectl describe pod <pending-pod>` → Events | `0/N nodes available: insufficient cpu` → Cluster Autoscaler needed; or reduce `resources.requests.cpu` |
