---
name: Helm Basics
description: Core Helm concepts, install workflow, operations, failure modes, and project chart map — loaded at the start of every Helm task
type: reference
originSessionId: 99cc013c-6898-4fc5-8d30-a005a9d38295
---
## 1. Three Core Concepts

| Concept | One-sentence definition |
|---|---|
| **Chart** | Versioned package of K8s manifests with parameterized values (`values.yaml`) |
| **Release** | Named installed instance of a chart, tracked in the cluster with full revision history |
| **Repository** | Remote server hosting versioned charts — same mental model as apt, npm, or pip |

---

## 2. Install Workflow — Exact Commands

```powershell
# 1. Add repo (one-time)
helm repo add bitnami https://charts.bitnami.com/bitnami

# 2. Fetch latest index
helm repo update

# 3. Find the chart
helm search repo redis

# 4. Inspect values before writing overrides
helm show values bitnami/redis | Select-String -Context 0,8 "auth:"
helm show values bitnami/redis | Select-String -Context 0,5 "persistence:"
helm show values bitnami/redis | Select-String -Context 0,5 "resources:"

# 5. Write overrides file (only keys that differ from default)
# → my-redis-values.yaml

# 6. Dry-run — MANDATORY before every install
helm template my-redis bitnami/redis -f my-redis-values.yaml --debug

# 7. Install
helm install my-redis bitnami/redis -f my-redis-values.yaml -n default

# 8. READ NOTES.txt output — contains exact service hostname and connection test command
```

---

## 3. Five Operations

| Operation | Syntax | Notes |
|---|---|---|
| **install** | `helm install <release> <chart> -f values.yaml -n <ns>` | Creates revision 1 |
| **upgrade** | `helm upgrade <release> <chart> -f values.yaml -n <ns>` | Increments revision |
| **rollback** | `helm rollback <release> <revision> -n <ns>` | Creates new revision, never rewrites history |
| **list** | `helm list -n <ns>` | Shows name, revision, status, chart, app version |
| **uninstall** | `helm uninstall <release> -n <ns>` | Removes all objects; add `--keep-history` to retain Secrets |

---

## 4. Values Override Precedence

```
chart default values.yaml  →  -f overrides.yaml  →  --set key=value
        (lowest priority)                              (highest priority)
```

- Rightmost wins
- Never use `--set` for passwords — leaks to shell history and Helm release Secret in etcd
- Use `auth.existingSecret` + `kubectl create secret` instead

---

## 5. How to Find Service Name After Install

```powershell
# Method 1 — read NOTES.txt (printed after helm install/upgrade)
# Contains exact DNS name, e.g.: my-redis-master.default.svc.cluster.local

# Method 2 — query live cluster
kubectl get svc -n default | Select-String "my-redis"

# Pattern: [release-name]-[chart-component]
# helm install my-redis bitnami/redis  →  service: my-redis-master
# helm install my-pg   bitnami/postgresql → service: my-pg-postgresql
```

---

## 6. Common Failure Modes

| Symptom | Cause | Fix |
|---|---|---|
| Pod `Pending`, PVC unbound | No StorageClass in minikube | Add `--set master.persistence.enabled=false` |
| `Error: cannot re-use a name` | Release already exists | Use `helm upgrade --install <release> <chart> -f values.yaml` |
| `Error: secret "X" not found` | K8s Secret not created before install | `kubectl apply -f secret.yaml` first, then install |
| App `Connection refused` to Redis | Wrong hostname (using Docker Compose name) | Read NOTES.txt; run `nslookup my-redis-master` from inside app Pod |
| `NOAUTH Authentication required` | Password missing from connection URL | Check `auth.existingSecret` and Secret key name match |
| `STATUS: failed` in `helm list` | Upgrade failed mid-way | `helm rollback <release>` immediately; never leave failed in production |
| Pod `ImagePullBackOff` after upgrade | Wrong image tag in values | `helm rollback <release> <last-good-revision>` |

---

## 7. Project Installed Charts

| Release name | Chart | Service hostname (in-cluster) | Provides |
|---|---|---|---|
| `my-redis` | `bitnami/redis` | `my-redis-master.default.svc.cluster.local:6379` | LangGraph checkpoint store for qna-agent |

**Env var in qna-agent ConfigMap:**
```
REDIS_URL = redis://my-redis-master:6379/0
```
*(short DNS form — works within same namespace `default`)*

**Auth:** Credential in K8s Secret `redis-auth-secret`, key `redis-password`.
Chart references it via `auth.existingSecret`.

---

## 8. Release History Model

```
helm install   → revision 1  (Secret: sh.helm.release.v1.<release>.v1)
helm upgrade   → revision 2  (Secret: sh.helm.release.v1.<release>.v2)
helm upgrade   → revision 3  (failed — Secret still written)
helm rollback  → revision 4  (copy of revision 2 — history never rewritten)
```

- History survives pod restarts — stored as K8s Secrets in etcd
- `helm rollback` reverts ALL objects atomically (StatefulSet + Service + ConfigMap + PVC refs)
- `kubectl rollout undo` only reverts the Deployment — use `helm rollback` for Helm-managed stacks

---

## 9. Dry-run Discipline

```powershell
# Always render before applying
helm template <release> <chart> -f values.yaml --debug | more

# Verify before upgrade
helm diff upgrade <release> <chart> -f values.yaml   # requires helm-diff plugin

# Watch rollout after upgrade
kubectl rollout status statefulset/<release>-master -n <ns> --timeout=90s
```
