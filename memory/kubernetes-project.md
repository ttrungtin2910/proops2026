---
name: Kubernetes project state — RAG chatbot Day 14
description: K8s service map, DNS patterns, apply order, ConfigMap/Secret rules, failures hit and fixed — Day 14 session
type: project
originSessionId: ef4cbca3-0013-4b96-a80e-b9fad958686b
---
## 1. Service map — K8s names, ports, images

| Role | K8s Service name | Namespace | Port | Image |
|---|---|---|---|---|
| hook-gateway | `hook-gateway` | default | 8080 | ttrungtin2910/hook-gateway:day10 |
| qna-agent | `qna-agent` | default | 8000 | ttrungtin2910/qna-agent:day10 |
| websocket-responder | `websocket-responder` | default | 8085 | ttrungtin2910/websocket-responder:day10 |
| frontend (nginx BFF) | `frontend` | default | 80 | ttrungtin2910/frontend:day10 |
| kafka | `kafka` | default | 9092 | confluentinc/cp-kafka:7.6.0 |
| zookeeper | `zookeeper` | default | 2181 | confluentinc/cp-zookeeper:7.6.0 |
| redis | `redis` | default | 6379 | redis:7-alpine |
| mongodb | `mongodb` | default | 27017 | mongo:7 |
| milvus | `milvus` | default | 19530 | milvusdb/milvus:v2.4.0 |
| minio | `minio` | default | 9000 | minio/minio:RELEASE.2023-03-13T19-46-17Z |
| etcd | `etcd` | default | 2379 | quay.io/coreos/etcd:v3.5.5 |

All services: `type: ClusterIP`, namespace: `default`

Ingress: `ragchatbot-ingress`, class `nginx`, host `ragchatbot.local`, ADDRESS `192.168.49.2`
Single rule: `/ → frontend:80` (frontend nginx handles all backend proxying internally)

---

## 2. ConfigMap vs Secret rule

- **ConfigMap (`data:`)** — non-sensitive config: URLs, topic names, model names, runtime flags. Plain strings, no encoding.
- **Secret (`stringData:`)** — credentials that would be a liability if leaked: API keys, JWT secrets. K8s encodes `stringData` to base64 internally.
- **Rule:** never commit Secret YAML with real values. Always create via:
  ```powershell
  kubectl create secret generic <name> --from-literal=KEY=value --dry-run=client -o yaml | kubectl apply -f -
  ```

### ConfigMap contents per service

| ConfigMap | Keys |
|---|---|
| `hook-gateway-cm` | `KAFKA_BOOTSTRAP_SERVERS`, `KAFKA_TOPIC_QNA_INCOMING`, `APP_ENV`, `PORT`, `RATE_LIMIT_PERMIT`, `RATE_LIMIT_WINDOW_SECONDS`, `JWT_TOKEN_LIFETIME_HOURS` |
| `qna-agent-cm` | `KAFKA_BOOTSTRAP_SERVERS`, `KAFKA_TOPIC_QNA_INCOMING`, `KAFKA_TOPIC_RESPONSE`, `MILVUS_HOST`, `MILVUS_PORT`, `MILVUS_COLLECTION_NAME`, `REDIS_URL`, `MONGODB_URI`, `OPENAI_CHAT_MODEL`, `OPENAI_EMBEDDING_MODEL`, `KNOWLEDGE_BASE_PATH`, `RUNTIME_STATE_DIR`, `APP_ENV` |
| `websocket-responder-cm` | `KAFKA_BOOTSTRAP_SERVERS`, `KAFKA_TOPIC_RESPONSE`, `APP_ENV` |

### Secret contents per service

| Secret | Keys |
|---|---|
| `hook-gateway-secret` | `JWT_SECRET` |
| `qna-agent-secret` | `OPENAI_API_KEY` |
| `websocket-responder-secret` | `JWT_SECRET` |

**Critical:** `hook-gateway-secret.JWT_SECRET` and `websocket-responder-secret.JWT_SECRET` must be the same value — hook-gateway signs tokens, websocket-responder verifies them.

**frontend** has no ConfigMap or Secret — `nginx.conf` is baked into the image; all backend URLs are K8s DNS names hardcoded in nginx config.

---

## 3. In-cluster DNS pattern

```
<service-name>.<namespace>.svc.cluster.local:<port>
```

CoreDNS search domains inside pods include `default.svc.cluster.local`, so **short names always work**:

| Short name used in config | Resolves to |
|---|---|
| `kafka:9092` | `kafka.default.svc.cluster.local:9092` |
| `milvus:19530` | `milvus.default.svc.cluster.local:19530` |
| `redis://redis:6379/0` | `redis.default.svc.cluster.local:6379` |
| `mongodb://mongodb:27017` | `mongodb.default.svc.cluster.local:27017` |
| `hook-gateway:8080` | `hook-gateway.default.svc.cluster.local:8080` |
| `websocket-responder:8085` | `websocket-responder.default.svc.cluster.local:8085` |

DNS record exists as soon as the Service object is created — before the pod is ready. DNS-only checks (`nslookup`) always pass early; use TCP checks (`nc -z host port`) to verify actual readiness.

---

## 4. Apply order (dependency graph)

| Wave | Files to apply | Reason |
|---|---|---|
| 1 | `k8s/infra/etcd.yaml`, `k8s/infra/zookeeper.yaml`, `k8s/infra/minio.yaml`, `k8s/infra/redis.yaml`, `k8s/infra/mongodb.yaml` | No dependencies |
| 2 | `k8s/infra/milvus.yaml` | Needs etcd:2379 + minio:9000 |
| 2 | `k8s/infra/kafka.yaml` | Needs zookeeper:2181 |
| 3 | ConfigMaps + Secrets for all app services | Must exist before Deployments |
| 4 | `k8s/deployments/hook-gateway-deployment.yaml` + `k8s/services/hook-gateway-svc.yaml` | Needs kafka Running |
| 4 | `k8s/deployments/websocket-responder-deployment.yaml` + `k8s/services/websocket-responder-svc.yaml` | Needs kafka Running |
| 5 | `k8s/deployments/qna-agent-deployment.yaml` + `k8s/services/qna-agent-svc.yaml` | Needs milvus + kafka (initContainers enforce via TCP) |
| 6 | `k8s/deployments/frontend-deployment.yaml` + `k8s/services/frontend-svc.yaml` | Standalone nginx, no hard deps |
| 7 | `k8s/ingress/ragchatbot-ingress.yaml` | Needs frontend Service to exist |

**After fresh qna-agent pod start** — must run corpus migration or `corpus_ready=False`:
```powershell
kubectl exec deploy/qna-agent -- python -m app.cli.migrate
```

**Pre-create Kafka topics** before starting consumers to avoid offset race condition:
```powershell
kubectl exec deploy/kafka -- kafka-topics --bootstrap-server kafka:9092 --create --if-not-exists --topic dev.qna.incoming.msg --partitions 1 --replication-factor 1
kubectl exec deploy/kafka -- kafka-topics --bootstrap-server kafka:9092 --create --if-not-exists --topic dev.response.msg --partitions 1 --replication-factor 1
```

---

## 5. Critical YAML patterns per service

### kafka — two mandatory settings
```yaml
spec:
  enableServiceLinks: false   # REQUIRED — prevents K8s injecting KAFKA_PORT env var
  containers:
    - name: kafka
      # NO readinessProbe — would cause self-connect deadlock (see Failures section)
      env:
        - name: KAFKA_ADVERTISED_LISTENERS
          value: "PLAINTEXT://kafka:9092"   # must match K8s Service name
        - name: KAFKA_LISTENERS
          value: "PLAINTEXT://0.0.0.0:9092"
```

### qna-agent — initContainers for TCP dependency check
```yaml
spec:
  initContainers:
    - name: wait-for-milvus
      image: busybox:1.28
      command: ['sh', '-c', 'until nc -z milvus 19530; do echo waiting; sleep 5; done']
    - name: wait-for-kafka
      image: busybox:1.28
      command: ['sh', '-c', 'until nc -z kafka 9092; do echo waiting; sleep 5; done']
```

### frontend — no ConfigMap/Secret; nginx.conf routing table
```
/webchat    → http://hook-gateway:8080/webchat         (POST, with JWT)
/auth/token → http://hook-gateway:8080/auth/token      (GET, no auth)
/api/health → http://hook-gateway:8080/health          (GET, no auth)
/ws         → http://websocket-responder:8085/ws       (WebSocket, Upgrade headers)
/           → Angular SPA static (try_files)
```
Source: [front-end/nginx.conf](../../../../../14-AIOps_TinTT33/front-end/nginx.conf)

### Ingress — single rule routes everything to frontend
```yaml
spec:
  ingressClassName: nginx
  rules:
    - host: ragchatbot.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
```

---

## 6. Kafka topic names

| Env var | Value | Flow |
|---|---|---|
| `KAFKA_TOPIC_QNA_INCOMING` | `dev.qna.incoming.msg` | hook-gateway → qna-agent |
| `KAFKA_TOPIC_RESPONSE` | `dev.response.msg` | qna-agent → websocket-responder |

---

## 7. Failures hit + fixes

| Failure symptom | Root cause | Fix |
|---|---|---|
| Kafka `CrashLoopBackOff` on fresh cluster | K8s auto-injects `KAFKA_PORT=tcp://10.x.x.x:9092` env var into all pods sharing the `kafka` Service namespace; Confluent image treats `KAFKA_PORT` as legacy port config and crashes | `enableServiceLinks: false` in kafka Deployment pod spec |
| Kafka `NodeExistsException` after pod restart | ZooKeeper keeps `/brokers/ids/1` ephemeral node alive from old session; new pod can't register as broker 1 | Scale to 0 → force-delete pods → `kubectl exec deploy/zookeeper -- bash -c "zookeeper-shell localhost:2181 deleteall /brokers/ids/1"` → scale back to 1 |
| Kafka readinessProbe deadlock | Kafka controller self-connects via `kafka:9092` Service; readinessProbe blocks pod from being added to Service endpoints until probe passes — but probe can only pass after the Service has endpoints | Remove readinessProbe from kafka Deployment entirely |
| qna-agent `CrashLoopBackOff` (blocks port 8000) | `MilvusClient.__init__` calls `_ensure_collection()` synchronously during module import; if Milvus not ready, this blocks uvicorn from binding port 8000 | initContainers with `nc -z milvus 19530` TCP check |
| initContainer `nslookup milvus` passes too early | K8s Service DNS record exists immediately after `kubectl apply`, even before the pod is healthy | Replace `nslookup milvus` with `nc -z milvus 19530` (TCP port check only passes when port is accepting connections) |
| websocket-responder receives message but `message dropped` | `auto.offset.reset=latest` — consumer started after message was published; missed it | Pre-create topics; send a new message after consumer is up and shows `partitions=[1]` |
| `topic dev.response.msg not found` | First-ever run: qna-agent hadn't published to that topic yet; auto-create race | Pre-create both topics with `kafka-topics --create --if-not-exists` before starting consumers |
| `base64 -d` not found in PowerShell | PowerShell has no `base64` command | `[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($val))` |
| `dial tcp 127.0.0.1:xxxxx: connectex: No connection` | Stale kubeconfig after minikube restart (old API server port) | `minikube update-context` then `minikube start --driver=docker` |
| `corpus_ready=False` after fresh pod | `migration-status.json` not present in `/workspace/.runtime/` | `kubectl exec deploy/qna-agent -- python -m app.cli.migrate` |
| websocket-responder stale Kafka ClusterIP after Kafka recreation | rdkafka client cached old IP | `kubectl rollout restart deployment/websocket-responder` |

---

## 8. Healthy stack signature (`kubectl get all`)

```
# Pods — 11 total, all must be 1/1 Running
pod/etcd-*                  1/1  Running   0
pod/frontend-*              1/1  Running   0
pod/hook-gateway-*          1/1  Running   (may show 1 restart from early Kafka race)
pod/kafka-*                 1/1  Running   0
pod/milvus-*                1/1  Running   0
pod/minio-*                 1/1  Running   0
pod/mongodb-*               1/1  Running   0
pod/qna-agent-*             1/1  Running   0
pod/redis-*                 1/1  Running   0
pod/websocket-responder-*   1/1  Running   0
pod/zookeeper-*             1/1  Running   0

# Deployments — all READY 1/1, AVAILABLE 1
# Services — all ClusterIP, no <pending> EXTERNAL-IP
# Ingress — ADDRESS 192.168.49.2, no <pending>
# Stale ReplicaSets with DESIRED 0 — normal after rollout restarts, ignore
```

---

## 9. Access from Windows host

```powershell
# Option A — port-forward (quick, no hosts file change)
kubectl port-forward svc/frontend 4200:80
# → http://localhost:4200

# Option B — direct to hook-gateway for API testing
kubectl port-forward svc/hook-gateway 8080:8080
# → http://localhost:8080/auth/token, /webchat, /health

# Option C — minikube tunnel (persistent browser access via hostname)
minikube tunnel   # run in separate terminal, requires admin
# Add to C:\Windows\System32\drivers\etc\hosts:
#   127.0.0.1  ragchatbot.local
# → http://ragchatbot.local
```

---

## 10. E2E verification sequence (PowerShell)

```powershell
# Step 1 — start port-forward
Start-Process -NoNewWindow -FilePath "kubectl" -ArgumentList "port-forward","svc/hook-gateway","8080:8080"
Start-Sleep -Seconds 4

# Step 2 — get JWT token
$token = (Invoke-RestMethod -Method POST `
  -Uri "http://localhost:8080/auth/token" `
  -ContentType "application/json" `
  -Body '{"user_id":"v","session_id":"s"}').token

# Step 3 — send message  ← field name is 'text', NOT 'message'
Invoke-RestMethod -Method POST `
  -Uri "http://localhost:8080/webchat" `
  -ContentType "application/json" `
  -Headers @{Authorization="Bearer $token"} `
  -Body '{"text":"xin chao"}'
# Expected: {"status":"accepted"}

# Step 4 — verify qna-agent processed it (OpenAI calls appear)
kubectl logs deployment/qna-agent --tail=20
# Look for:
#   POST https://api.openai.com/v1/embeddings "HTTP/1.1 200 OK"
#   POST https://api.openai.com/v1/chat/completions "HTTP/1.1 200 OK"

# Step 5 — verify websocket-responder received Kafka response
kubectl logs deployment/websocket-responder --tail=10
# Look for: Kafka message received requestId=...
# Note: "message dropped" is expected here (no WS client in API-only test)
```

**Why `text` not `message`:** WebChatRequest model has field `Text` — defined in [hook-gateway/HookGateway.Web.Api/Models/WebChatRequest.cs:5](../../../../../14-AIOps_TinTT33/hook-gateway/HookGateway.Web.Api/Models/WebChatRequest.cs)

---

## 11. File locations (k8s/ directory)

```
k8s/
├── configmaps/
│   ├── hook-gateway-cm.yaml          # 7 keys
│   ├── qna-agent-cm.yaml             # 13 keys
│   └── websocket-responder-cm.yaml   # 3 keys
├── secrets/
│   ├── hook-gateway-secret.yaml      # template only, JWT_SECRET
│   ├── qna-agent-secret.yaml         # template only, OPENAI_API_KEY
│   └── websocket-responder-secret.yaml  # template only, JWT_SECRET
├── deployments/
│   ├── hook-gateway-deployment.yaml
│   ├── qna-agent-deployment.yaml     # has initContainers
│   ├── websocket-responder-deployment.yaml
│   └── frontend-deployment.yaml
├── services/
│   ├── hook-gateway-svc.yaml         # ClusterIP :8080
│   ├── qna-agent-svc.yaml            # ClusterIP :8000
│   ├── websocket-responder-svc.yaml  # ClusterIP :8085
│   └── frontend-svc.yaml             # ClusterIP :80
├── infra/
│   ├── etcd.yaml
│   ├── zookeeper.yaml
│   ├── kafka.yaml                    # enableServiceLinks:false, no readinessProbe
│   ├── redis.yaml
│   ├── mongodb.yaml
│   ├── minio.yaml
│   └── milvus.yaml
└── ingress/
    └── ragchatbot-ingress.yaml       # single rule: / → frontend:80
```
