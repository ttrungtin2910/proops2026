# Daily Log — Tin (Trần Trung Tín) — Day 14 — 05 May 2026

## Today's Assignment (Day 14 — K8s Practice: Deploy Real Project)
- [x] Q1 — Map every service from DOP: classify each env var as ConfigMap or Secret
- [x] Q2 — Write and apply ConfigMaps; understand `envFrom` vs `env.valueFrom.configMapKeyRef`
- [x] Q3 — Create Secrets via `kubectl create secret` — never commit real values to YAML
- [x] Q4 — Deploy first service: Deployment references ConfigMap + Secret; verify injection
- [x] Q5 — Update ConfigMaps: Docker Compose hostnames → K8s in-cluster DNS names
- [x] Q6 — Deploy remaining services in dependency order; troubleshoot startup failures
- [x] Q7 — Write Ingress, test every path; debug 502 via `kubectl get endpoints`
- [x] Q8 — Make real end-to-end API call; write `memory/kubernetes-project.md`

## Environment
Windows 11 Pro, Claude Code CLI inside VSCode. minikube with Docker driver. `minikube addons enable ingress` active. All 11 services deployed (4 app + 7 infra) to `default` namespace. Full stack Running 1/1 and E2E verified: POST /webchat → OpenAI → Kafka → WebSocket response confirmed.

## Completed

- [x] **Q1 — Env var classification (ConfigMap vs Secret):**
  Rule: "Would this value cause a security incident if it appeared in a CI log?" No → ConfigMap; Yes → Secret.

  | Service | ConfigMap keys | Secret keys |
  |---|---|---|
  | hook-gateway | KAFKA_BOOTSTRAP_SERVERS, KAFKA_TOPIC_QNA_INCOMING, APP_ENV, PORT, RATE_LIMIT_PERMIT, RATE_LIMIT_WINDOW_SECONDS, JWT_TOKEN_LIFETIME_HOURS | JWT_SECRET |
  | qna-agent | KAFKA_BOOTSTRAP_SERVERS, KAFKA_TOPIC_QNA_INCOMING, KAFKA_TOPIC_RESPONSE, MILVUS_HOST, MILVUS_PORT, MILVUS_COLLECTION_NAME, REDIS_URL, MONGODB_URI, OPENAI_CHAT_MODEL, OPENAI_EMBEDDING_MODEL, KNOWLEDGE_BASE_PATH, RUNTIME_STATE_DIR, APP_ENV | OPENAI_API_KEY |
  | websocket-responder | KAFKA_BOOTSTRAP_SERVERS, KAFKA_TOPIC_RESPONSE, APP_ENV | JWT_SECRET |
  | frontend | — (none) | — (none) |

  Frontend has no env vars — all backend URLs are baked into `nginx.conf` inside the image. Ingress only needs 1 rule (`/ → frontend:80`) because nginx acts as BFF proxy and handles all internal routing via K8s DNS.

- [x] **Q2 — Write and apply ConfigMaps:**
  Three ConfigMaps written and applied: `hook-gateway-cm` (7 keys), `qna-agent-cm` (13 keys), `websocket-responder-cm` (3 keys). All use `data:` field with plain strings. Critical mistake to avoid: `stringData:` is for Secrets only (K8s encodes it to base64 internally). ConfigMaps do NOT use `stringData` — only `data:`.

  Two injection methods in Deployment:
  - `envFrom.configMapRef.name: hook-gateway-cm` — injects ALL keys at once as env vars. Zero Deployment change required when ConfigMap changes — just `kubectl apply` the ConfigMap + `rollout restart`.
  - `env.valueFrom.configMapKeyRef` — pulls one key at a time, allows renaming. Use when pulling from multiple ConfigMaps or when a key needs renaming.

  Critical: `configMapRef.name` must match `metadata.name` exactly — one typo → Pod stuck in `CreateContainerConfigError`. Diagnosis: `kubectl describe pod <name>` → Events section shows `Error: configmap "hook-gatewy-cm" not found`.

- [x] **Q3 — Create Secrets via kubectl (never YAML with real values):**
  ```powershell
  kubectl create secret generic hook-gateway-secret `
    --from-literal=JWT_SECRET=<value> `
    --dry-run=client -o yaml | kubectl apply -f -
  ```
  `--dry-run=client -o yaml | kubectl apply -f -` makes the operation idempotent — safe to re-run. The real value never touches a file, never appears in git history.

  Three Secrets created: `hook-gateway-secret` (JWT_SECRET), `qna-agent-secret` (OPENAI_API_KEY), `websocket-responder-secret` (JWT_SECRET). Critical: `hook-gateway-secret` and `websocket-responder-secret` must share the exact same JWT_SECRET — hook-gateway signs tokens, websocket-responder verifies them with the same key.

  Verify secret value in PowerShell (`base64 -d` not available on Windows):
  ```powershell
  $b64 = kubectl get secret qna-agent-secret -o jsonpath='{.data.OPENAI_API_KEY}'
  [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($b64))
  ```

- [x] **Q4 — Deploy first service (hook-gateway) with ConfigMap + Secret wiring:**
  Deployment spec pattern used for all app services:
  ```yaml
  envFrom:
    - configMapRef:
        name: hook-gateway-cm     # injects all 7 keys at once
  env:
    - name: JWT_SECRET
      valueFrom:
        secretKeyRef:
          name: hook-gateway-secret
          key: JWT_SECRET
  ```
  Wiring proof — seeing Pod `Running 1/1` is NOT enough. Must verify injection:
  ```powershell
  kubectl exec deploy/hook-gateway -- env | Select-String "KAFKA"
  # Must show: KAFKA_BOOTSTRAP_SERVERS=kafka:9092
  ```
  livenessProbe + readinessProbe both on `GET /health` port 8080. `initialDelaySeconds: 20/15` buffer for .NET 8 cold-start (without this, K8s kills the pod before ASP.NET Core finishes binding the port).

- [x] **Q5 — Update ConfigMaps to K8s in-cluster DNS names:**
  Pattern: `<service-name>.<namespace>.svc.cluster.local:<port>`. CoreDNS search domains inside pods include `default.svc.cluster.local`, so short names work: `kafka:9092`, `milvus:19530`, `redis:6379`.

  For this project: Docker Compose service names and K8s Service `metadata.name` values are identical — so ConfigMap values (`kafka:9092`, `milvus:19530`, `redis://redis:6379/0`) required no changes. The key insight: this works because the K8s Service names were deliberately chosen to match Docker Compose hostnames. If they didn't match, the old hostname would silently fail inside the container.

  DNS record exists as soon as `kubectl apply` creates the Service — before the Pod is healthy. DNS-only check (`nslookup kafka`) always passes early. TCP check (`nc -z kafka 9092`) only passes when the port actually accepts connections. Use TCP for initContainers.

- [x] **Q6 — Deploy all services in dependency order + 5 critical failures debugged:**

  **Apply order (6 waves):**
  | Wave | Services | Dependency |
  |---|---|---|
  | 1 | etcd, zookeeper, minio, redis, mongodb | none |
  | 2 | milvus | etcd + minio Running |
  | 2 | kafka | zookeeper Running |
  | 3 | hook-gateway, websocket-responder | kafka Running |
  | 4 | qna-agent | milvus + kafka (initContainers enforce via TCP) |
  | 5 | frontend | none (standalone nginx) |
  | 6 | Ingress | frontend Service exists |

  **Five critical failures hit and fixed:**

  **(1) Kafka CrashLoopBackOff — K8s Service link injection:**
  K8s automatically injects `KAFKA_PORT=tcp://10.98.132.83:9092` env var into all pods in the same namespace as the `kafka` Service. Confluent cp-kafka image interprets `KAFKA_PORT` as a legacy Docker-links port configuration and crashes with it. This never happens in Docker Compose.
  Fix: `enableServiceLinks: false` in kafka Deployment pod spec. Non-negotiable for Confluent images.

  **(2) Kafka NodeExistsException — ZooKeeper stale ephemeral node:**
  After a Kafka pod restart, ZooKeeper keeps `/brokers/ids/1` ephemeral node alive from the previous session. New pod can't register as broker 1.
  Fix: `kubectl scale deployment/kafka --replicas=0` → force delete pods → `kubectl exec deploy/zookeeper -- bash -c "zookeeper-shell localhost:2181 deleteall /brokers/ids/1"` → scale back to 1. (`rmr` is deprecated in newer ZK → use `deleteall`)

  **(3) Kafka readinessProbe deadlock:**
  Kafka controller self-connects via `kafka:9092` Service at startup. readinessProbe blocks Pod from being added to Service endpoints until probe passes — but probe can only pass after Kafka starts, which requires the Service to have endpoints. Chicken-and-egg.
  Fix: Remove readinessProbe from kafka Deployment entirely. No probe is the correct configuration for Kafka on K8s — this is not a limitation, it is the intended design.

  **(4) qna-agent CrashLoopBackOff — MilvusClient blocks uvicorn:**
  `MilvusClient.__init__` calls `_ensure_collection()` synchronously during Python module import. When Milvus isn't ready at import time, this call blocks and prevents uvicorn from binding port 8000, causing CrashLoopBackOff.
  Fix: initContainers with TCP connectivity check that holds the main container until Milvus actually accepts connections:
  ```yaml
  initContainers:
    - name: wait-for-milvus
      image: busybox:1.28
      command: ['sh', '-c', 'until nc -z milvus 19530; do echo waiting for milvus:19530; sleep 5; done']
    - name: wait-for-kafka
      image: busybox:1.28
      command: ['sh', '-c', 'until nc -z kafka 9092; do echo waiting for kafka:9092; sleep 5; done']
  ```

  **(5) initContainer `nslookup` check passes too early:**
  First attempt used `nslookup milvus` in the initContainer. K8s creates the Service DNS record the moment `kubectl apply -f milvus.yaml` runs — before the Milvus pod is healthy. nslookup resolves immediately, initContainer exits, main container starts, Milvus still not ready → crash again.
  Fix: Changed to `nc -z milvus 19530` — TCP port check, only passes when something is actually listening on that port.

- [x] **Q7 — Write Ingress and test paths:**
  Single rule: `/ → frontend:80`. Frontend nginx handles all backend routing internally via K8s DNS. No per-backend Ingress rules needed.

  nginx.conf routing table baked into the frontend image:
  ```
  /webchat    → http://hook-gateway:8080/webchat         (POST, requires JWT)
  /auth/token → http://hook-gateway:8080/auth/token      (GET, no auth)
  /api/health → http://hook-gateway:8080/health          (GET, no auth)
  /ws         → http://websocket-responder:8085/ws       (WebSocket, Upgrade headers)
  /           → Angular SPA static files (try_files)
  ```

  Critical annotations for WebSocket (without these, nginx kills idle WS connections after 60s default):
  ```yaml
  nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
  nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
  ```

  502 debug sequence: `kubectl get endpoints frontend` — if output shows `<none>`, selector mismatch between `spec.backend.service.name` and `Service metadata.name`. `kubectl describe ingress ragchatbot-ingress` shows all active routing rules.

- [x] **Q8 — End-to-end API call + memory/kubernetes-project.md:**
  Full chain verified via PowerShell (port-forwarding hook-gateway 8080):
  ```powershell
  # Step 1 — get JWT
  $token = (Invoke-RestMethod -Method POST -Uri "http://localhost:8080/auth/token" `
    -ContentType "application/json" -Body '{"user_id":"v","session_id":"s"}').token

  # Step 2 — send message (field name is 'text' NOT 'message')
  Invoke-RestMethod -Method POST -Uri "http://localhost:8080/webchat" `
    -ContentType "application/json" `
    -Headers @{Authorization="Bearer $token"} `
    -Body '{"text":"xin chao"}'
  # Response: {"status":"accepted"}
  ```
  qna-agent logs: `POST https://api.openai.com/v1/embeddings "200 OK"` + `POST https://api.openai.com/v1/chat/completions "200 OK"`.
  websocket-responder logs: `Kafka message received requestId=... conversationId=...`.
  Full chain confirmed: Ingress → frontend nginx → hook-gateway → Kafka → qna-agent → OpenAI → Kafka → websocket-responder → WebSocket push.

  `memory/kubernetes-project.md` written with 11 sections: service map, ConfigMap/Secret rule, in-cluster DNS pattern (all services), apply order wave table, critical YAML patterns per service, Kafka topic names, 9 failures+fixes table, healthy stack signature, Windows host access options, E2E PowerShell verification script, file location tree.

## Not Completed
| Item | Reason |
|---|---|
| Day 15 (Helm intro) | Day 14 took full session — 5 critical Kafka/infra failures to debug |

## Extra Things Explored

- **`enableServiceLinks: false` — Kafka-specific K8s gotcha:**
  K8s injects `<SERVICE_NAME>_PORT=tcp://IP:PORT` env vars for every Service in the namespace into every Pod. This is normally invisible. For Confluent cp-kafka, `KAFKA_PORT` is a legacy Docker-link variable that overrides the advertised listener config, silently breaking the broker. The only fix without patching the image is `enableServiceLinks: false`. This is not documented in the Confluent image README — discoverable only by reading crash logs and recognizing `KAFKA_PORT=tcp://10.98.132.83:9092` should not exist.

- **Frontend nginx as BFF (Backend for Frontend):**
  The frontend Pod is not just serving static files — it proxies all API and WebSocket traffic internally. Angular uses relative URLs (`apiUrl: ''`, `wsUrl: '/ws'`), so all requests go to the same origin. nginx routes internally via K8s DNS to ClusterIP services. This keeps all backend services invisible from outside the cluster — no CORS, no external backend URLs. Ingress needs only 1 rule.

- **qna-agent corpus migration after fresh pod:**
  initContainers verify TCP connectivity (Milvus port open). They don't verify data readiness. `migration-status.json` in `/workspace/.runtime/` marks the knowledge base as loaded. On a fresh pod without this file, `corpus_ready=False` → questions return empty answers.
  Fix: `kubectl exec deploy/qna-agent -- python -m app.cli.migrate`

- **Kafka consumer offset timing:**
  `auto.offset.reset=latest` means websocket-responder starts reading from the end of the topic. If messages are published while the consumer has `partitions=0` (during restart/reassignment), those messages are skipped permanently. Pre-creating topics before starting consumers and waiting for `partitions=[1]` before sending test messages avoids this.

## Artifacts Built Today

- [x] `k8s/configmaps/hook-gateway-cm.yaml` — 7 keys
- [x] `k8s/configmaps/qna-agent-cm.yaml` — 13 keys
- [x] `k8s/configmaps/websocket-responder-cm.yaml` — 3 keys
- [x] `k8s/secrets/hook-gateway-secret.yaml` — template only, real values via kubectl
- [x] `k8s/secrets/qna-agent-secret.yaml` — template only
- [x] `k8s/secrets/websocket-responder-secret.yaml` — template only
- [x] `k8s/deployments/hook-gateway-deployment.yaml`
- [x] `k8s/deployments/qna-agent-deployment.yaml` — with initContainers (wait-for-milvus, wait-for-kafka)
- [x] `k8s/deployments/websocket-responder-deployment.yaml`
- [x] `k8s/deployments/frontend-deployment.yaml`
- [x] `k8s/services/` — 4 ClusterIP Services (hook-gateway:8080, qna-agent:8000, websocket-responder:8085, frontend:80)
- [x] `k8s/infra/etcd.yaml`, `zookeeper.yaml`, `kafka.yaml` (enableServiceLinks:false, no readinessProbe), `redis.yaml`, `mongodb.yaml`, `minio.yaml`, `milvus.yaml`
- [x] `k8s/ingress/ragchatbot-ingress.yaml` — single rule `/ → frontend:80`, WS timeout annotations
- [x] `memory/kubernetes-project.md` — 11 sections including 9 failures+fixes table, E2E sequence

## How I Used Claude Code Today

Day 14 was a full hands-on deployment session — the largest K8s lab to date (11 services, 22+ YAML files). The workflow was structured as a dependency-ordered deployment pipeline: infra waves first, app services second, Ingress last. Each wave was followed by `kubectl get pods -w` to observe readiness before proceeding.

Five critical failures were hit in sequence, each requiring different diagnostic tools: `kubectl logs` (Kafka crash), `kubectl exec` into ZooKeeper shell (stale ephemeral node), YAML diff (readinessProbe deadlock), initContainer debug sequence (MilvusClient blocking uvicorn). Each failure was documented immediately in `memory/kubernetes-project.md` before moving on — the memory file was built incrementally, not written at the end.

The Q8 E2E call (POST /webchat → OpenAI calls visible in qna-agent logs → Kafka message received in websocket-responder logs) was the acceptance gate. The stack wasn't "done" until that chain was verified. A health ping on `/health` would not have caught the Kafka consumer offset issue that caused missed messages.

## Blockers / Questions for Mentor
- qna-agent corpus migration must be run manually after every fresh pod start — is there a K8s Job or initContainer pattern to automate this, rather than `kubectl exec`?
- Kafka `auto.offset.reset=latest` caused missed messages during websocket-responder restart. Should the default be `earliest` for reliability? What are the tradeoffs with duplicate processing on re-read?

## Self Score
- Completion: 10/10 — all 8 questions done, 11 pods Running 1/1, E2E message flow confirmed end-to-end
- Understanding: 9/10 — the 5 Kafka failures gave deep insight into K8s-specific networking gotchas not visible in Docker Compose; initContainer TCP pattern, readinessProbe deadlock, BFF proxy architecture are now concrete mental models
- Energy: 8/10

## One Thing I Learned Today That Surprised Me

Kafka needs `enableServiceLinks: false` to run on Kubernetes at all — and this is not documented in the Confluent image README. I assumed K8s env var injection was a convenience feature applications would ignore if unused. In reality, Confluent's image actively looks for `KAFKA_PORT` as a legacy Docker-link mechanism. When K8s populates it with `tcp://10.98.132.83:9092`, the image silently overrides the advertised listener configuration and crashes. You only discover this by reading the broker startup logs carefully and recognizing that the variable shouldn't exist. The fix is one line in YAML but finding it requires understanding how K8s service link injection works AND how Confluent's legacy env var parsing works simultaneously.

---

## Tomorrow's Context Block

**Where I am:** Day 14 complete — all 4 project services (hook-gateway, websocket-responder, qna-agent, frontend) Running 1/1 in minikube default namespace. Full infra layer (Kafka, ZooKeeper, Redis, MongoDB, etcd, MinIO, Milvus) running in cluster. Ingress active at 192.168.49.2 (`ragchatbot.local`). E2E message flow confirmed: POST /webchat → OpenAI embeddings + chat completions → Kafka → WebSocket push. `memory/kubernetes-project.md` written with 11 sections including 9 failures+fixes table.

**What's in progress / unfinished:** Day 15 (Helm intro) not started. Redis is currently deployed via raw `k8s/infra/redis.yaml`. Day 15 requires: install Helm, `helm create myapp` to understand chart structure, add Bitnami repo, write `k8s/my-redis-values.yaml`, install `bitnami/redis` as release `my-redis`, read NOTES.txt for actual service hostname, update `qna-agent-cm.yaml` REDIS_URL from `redis:6379` to `my-redis-master:6379`, restart qna-agent, verify with `redis-cli -h my-redis-master ping` → PONG. Then: `helm upgrade` + `helm rollback`, `helm history` shows 2+ revisions, write `memory/helm-basics.md`.

**First thing to do tomorrow:** `helm version` to verify Helm is installed. If not: `winget install Helm.Helm`. Then `helm create myapp` → inspect all generated files (Chart.yaml, values.yaml, templates/, _helpers.tpl) → `helm template . --debug` to understand the render pipeline before any install. After that: `helm repo add bitnami https://charts.bitnami.com/bitnami && helm show values bitnami/redis | Select-String -Pattern "auth" -A 5` to identify the 3 keys to override.
