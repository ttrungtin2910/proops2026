# memory/kubernetes-project.md
**Project:** proops2026-mock-project (Chatbot Dịch Vụ Công)
**Written:** End of Day 14 — all IRD-01 + IRD-02 done criteria verified
**Format:** Tables and bullets only

---

## Service Table

| K8s Service Name | Deployment Name | Namespace | Service Port | Container Port | Image | Role |
| ---------------- | --------------- | --------- | ------------ | -------------- | ----- | ---- |
| hook-gateway-svc | hook-gateway | default | 8080 | 8080 | hook-gateway:latest | API gateway + JWT auth |
| websocket-responder-svc | websocket-responder | default | 8085 | 8085 | websocket-responder:latest | WebSocket push to clients |
| qna-agent-svc | qna-agent | default | 8000 | 8000 | qna-agent:latest | QnA AI agent |
| frontend-svc | frontend | default | 80 | 80 | frontend:latest | Angular SPA + nginx reverse proxy |

---

## ConfigMap vs Secret Rule

ConfigMap = safe to appear in a CI log or PR diff (hostnames, ports, topic names, model names).
Secret = would cause a security incident if exposed (JWT signing key, API keys, passwords).

---

## In-Cluster DNS Pattern

```
Within default namespace (short form — use this):
  hook-gateway-svc
  websocket-responder-svc
  qna-agent-svc
  frontend-svc

Fully qualified:
  hook-gateway-svc.default.svc.cluster.local

Project DNS map:
  hook-gateway-svc      → hook-gateway-svc:8080
  websocket-responder-svc → websocket-responder-svc:8085
  qna-agent-svc         → qna-agent-svc:8000
  frontend-svc          → frontend-svc:80
```

**Note:** Kafka, Redis, Milvus, MongoDB run on host (docker-compose) — accessed via `192.168.49.1` (host.minikube.internal IP) from inside pods.

---

## Apply Order

```
1. hook-gateway-svc     (no in-cluster dependency — Kafka on host)
2. websocket-responder-svc (no in-cluster dependency — Kafka on host)
3. qna-agent-svc        (no in-cluster dependency — all deps on host)
4. frontend-svc         (nginx must resolve hook-gateway-svc + websocket-responder-svc at startup)

Rule: frontend MUST be applied LAST — nginx resolves all proxy_pass upstreams at startup.
If hook-gateway-svc or websocket-responder-svc do not exist in DNS when nginx starts, frontend crashes.
```

Per service apply sequence:
```
kubectl apply -f [svc]-cm.yaml
kubectl create secret generic [svc]-secret --from-literal=KEY=value   (if needed)
kubectl apply -f [svc]-svc.yaml
kubectl apply -f [svc]-deployment.yaml
```

---

## Ingress Route Map

| Path | Backend Service | Port | Notes |
| ---- | --------------- | ---- | ----- |
| /api | hook-gateway-svc | 8080 | REST API routes |
| /webchat | hook-gateway-svc | 8080 | WebSocket widget |
| /auth | hook-gateway-svc | 8080 | JWT auth endpoints |
| /ws | websocket-responder-svc | 8085 | WebSocket upgrade |
| / | frontend-svc | 80 | SPA catch-all — MUST be last |

- No `rewrite-target` annotation — paths forwarded as-is to backends
- Path ordering is critical: specific paths before `/`

---

## Secrets Per Service

| Service | Secret Name | Keys |
| ------- | ----------- | ---- |
| hook-gateway | hook-gateway-secret | JWT_SECRET |
| qna-agent | qna-agent-secret | OPENAI_API_KEY |
| websocket-responder | none | — |
| frontend | none | — |

Created via `kubectl create secret generic` only — never in YAML files.

---

## Failures Hit + Fixes

| Symptom | Root Cause | Fix Applied |
| ------- | ---------- | ----------- |
| `BadRequest: unknown field "stringData"` on ConfigMap apply | `stringData` is a Secret-only field — invalid in ConfigMap | Changed all ConfigMap files to use `data` instead of `stringData` |
| `ErrImageNeverPull` | Images built in host Docker, not in minikube daemon | `minikube image load [image]:latest` for each service |
| `host not found in upstream "websocket-responder-svc"` — frontend crash | nginx resolves all `proxy_pass` upstreams at startup; websocket-responder not yet deployed | Deploy websocket-responder before applying frontend; restore `/ws` block after |
| `503` on `/api/health` via Ingress | hook-gateway readiness probe path was `/api/health` but actual endpoint is `/health` | Fixed probe path to `/health` in deployment YAML |
| hook-gateway `0/1` — Kafka unreachable | ConfigMap had `kafka-svc:29092` (K8s DNS) but Kafka runs on host docker-compose | Updated KAFKA_BOOTSTRAP_SERVERS to `192.168.49.1:9092`; updated Kafka ADVERTISED_LISTENERS to `192.168.49.1:9092` |
| Kafka container not starting via `docker compose up` | `bot-net` network label mismatch; `external: true` missing in docker-compose.yml | Added `external: true` to network definition; used `docker start` to bypass dependency healthcheck |
| Ingress conflict `host "_" and path "/api" already defined` | Previous `web-app` namespace had overlapping ingress rules | `kubectl delete namespace web-app` |
