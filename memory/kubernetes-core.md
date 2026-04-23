# Kubernetes Core

## Pod

- Smallest deployable unit. One or more containers running together on a node.
- Containers in a Pod **share**: network namespace (same IP, communicate via localhost), volumes.
- Containers in a Pod **do NOT share**: filesystem by default (unless a volume is mounted to both).
- **Never create Pods directly.** A bare Pod has no self-healing — if it dies, it stays dead. Always use Deployment (or Job/StatefulSet).

## Deployment

- Declares **desired state**: how many replicas, which image, what labels.
- Kubernetes creates a **ReplicaSet** per version. The Deployment owns the ReplicaSet; the ReplicaSet owns the Pods.
- Rolling update defaults: `maxUnavailable: 25%`, `maxSurge: 25%` (rounded down / up respectively).
- With 4 replicas: max 5 Pods alive at once, min 3 Ready at any point during rollout.
- If a new Pod fails readiness mid-rollout → rollout **stalls** (does not auto-rollback, does not continue).
- Rollback: `kubectl rollout undo deployment/<name>` — reuses previous ReplicaSet, no new image pull.
- Old ReplicaSets kept by default: `revisionHistoryLimit: 10`.

## Service

| Type | Reachable from | Connect via |
|------|---------------|-------------|
| ClusterIP (default) | Inside cluster only | ClusterIP:port |
| NodePort | Node IP + any node | `<node-ip>:<nodePort>` (30000–32767) |
| LoadBalancer | Internet (cloud LB) | External IP:port |
| ExternalName | Inside cluster only | Returns CNAME, no proxy |

- **Connection mechanism:** `spec.selector` on Service matches `metadata.labels` on Pods. Endpoints controller builds/maintains the IP list automatically.
- Three ports on NodePort: `port` (Service internal) → `targetPort` (container) → `nodePort` (node external). Omit `nodePort` → K8s assigns random port in range.
- During rolling update: new Pods added to Endpoints only when Ready; terminating Pods removed immediately. `preStop: sleep 5` absorbs kube-proxy propagation delay.

## Liveness vs Readiness Probes

**Liveness** — "Is the container still alive?" Fail → **restart container**. Check only the process health (simple `/healthz`), never external dependencies like DB.

**Readiness** — "Is the container ready to serve traffic?" Fail → **remove from Service Endpoints, no restart**. Safe to check DB connection here — if DB is down, Pod should stop receiving traffic.

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 25   # must exceed app warm-up time
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5    # start checking early, will fail until ready
  periodSeconds: 5
  failureThreshold: 3
  successThreshold: 1
```

- `initialDelaySeconds` on liveness **must be > app warm-up time** — too short causes CrashLoopBackOff before app finishes starting.
- `/healthz` → 200 if process alive, nothing else. `/ready` → 200 if app init done AND dependencies reachable.

## Kubectl Diagnostic Workflow

Run in this order. Each step reveals something the others miss.

1. `kubectl get pods -n <ns>` → STATUS + RESTARTS + AGE — tells you **which failure category** (crash, pending, not ready)
2. `kubectl describe pod <name> -n <ns>` → **Exit code of last crash** (Last State), scheduling failures, image pull errors in Events
3. `kubectl logs <name> -n <ns> --previous --tail=50` → **App's actual error message** — stack trace, missing env var, connection refused
4. `kubectl get events -n <ns> --sort-by='.lastTimestamp'` → **Node-level and scheduler failures** not attached to Pod (disk pressure, OOM on node, 0/N nodes available)
5. `kubectl exec -it <name> -n <ns> -- sh` → **Actual runtime values** — env vars injected, DNS resolution, file content at mount path (last resort, container must be Running)

## Diagnostic Lookup Table

| You see | First command | What you're looking for |
|---------|--------------|------------------------|
| `CrashLoopBackOff` | `kubectl logs <pod> --previous` | Stack trace / error message from last crash |
| `ImagePullBackOff` | `kubectl describe pod <pod>` | Events → "Failed to pull image" + reason (bad tag, no creds) |
| `0/1 READY` + Running | `kubectl describe pod <pod>` | Conditions → readiness probe failing; then check `/ready` endpoint |
| `Pending` | `kubectl get events --sort-by='.lastTimestamp'` | FailedScheduling → insufficient CPU/memory/taints |
| `Error` | `kubectl logs <pod> --previous` + `describe` | Exit code in Last State; OOMKilled = 137, app error = 1 |
| `Terminating` (stuck) | `kubectl describe pod <pod>` | Finalizers not cleared; check `metadata.finalizers` |
| `OOMKilled` | `kubectl get pod -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'` | Confirm OOMKilled; then raise `resources.limits.memory` |

## Minimal Manifests — Consistently Labeled

All three objects use `app: web` — Service selector targets both Pod and Deployment Pods.

```yaml
# Pod (direct — only for debugging, not production)
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: production
  labels:
    app: web
spec:
  containers:
  - name: app
    image: nginx:1.25.3
    ports:
    - containerPort: 8080
    resources:
      requests: { cpu: "100m", memory: "128Mi" }
      limits:   { cpu: "500m", memory: "256Mi" }
```

```yaml
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web           # MUST match template.metadata.labels
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: app
        image: nginx:1.25.3
        ports:
        - containerPort: 8080
        resources:
          requests: { cpu: "100m", memory: "128Mi" }
          limits:   { cpu: "500m", memory: "256Mi" }
        livenessProbe:
          httpGet: { path: /healthz, port: 8080 }
          initialDelaySeconds: 25
          periodSeconds: 10
        readinessProbe:
          httpGet: { path: /ready, port: 8080 }
          initialDelaySeconds: 5
          periodSeconds: 5
```

```yaml
# Service (ClusterIP — internal only)
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: production
spec:
  selector:
    app: web             # matches labels on Deployment Pods above
  ports:
  - port: 80
    targetPort: 8080
```

## Key Rules

- `selector.matchLabels` in Deployment **must** equal `template.metadata.labels` — mismatch causes validation error or infinite Pod creation loop.
- Never use `latest` image tag in production — pin to a specific version.
- Always set `resources.limits` — unset limits allow a Pod to consume entire node memory.
- `maxSurge: 100%` on resource-constrained cluster → doubles Pod count during rollout → node pressure → readiness failures → stalled rollout.
- Liveness probe failing because of DB down = restart loop. Readiness probe failing because of DB down = correct behavior.
