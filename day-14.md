# Daily Log — Vo Nhu Phuong & Tran Trung Tin — Day 14 — 23 Apr 2026

## Today's Assignment
K8s Practice: Deploy real project (hook-gateway, websocket-responder, qna-agent, frontend) to minikube with proper ConfigMap/Secret wiring + Ingress routing.

- [x] Classify all env vars per service (ConfigMap vs Secret)
- [x] Write and apply ConfigMaps for all 4 services
- [x] Create Secrets via kubectl create secret (no YAML)
- [x] Write and apply Deployments + Services for all 4 services
- [x] All Pods Running 1/1
- [x] Update connection strings to K8s DNS names
- [x] Write and apply Ingress, test all paths
- [x] End-to-end call: /webchat returns chatbot HTML, / returns Angular SPA
- [x] Write memory/kubernetes-project.md

## Completed
- [x] ConfigMaps for all 4 services (hook-gateway, websocket-responder, qna-agent, frontend)
- [x] Secrets: hook-gateway-secret (JWT_SECRET), qna-agent-secret (OPENAI_API_KEY)
- [x] All 4 Deployments + ClusterIP Services applied
- [x] All Pods Running 1/1 after debugging
- [x] Ingress with 5 routes (/api, /webchat, /auth, /ws, /) — ADDRESS: 192.168.49.2
- [x] ConfigMap wiring verified: kubectl exec -- env | grep KAFKA shows injected values
- [x] End-to-end: /webchat → 200 HTML, / → 200 Angular SPA
- [x] memory/kubernetes-project.md written with service table, DNS pattern, apply order, failures+fixes

## Not Completed
| Item | Reason | Time Spent |
| ---- | ------ | ---------- |
| Day 15 (Helm Redis) | Day 14 took full session | — |

## Extra Things Explored

- **Service startup depends on DNS readiness**  
  Some components (e.g., nginx) fail immediately if upstream services are not resolvable at startup → Kubernetes does not guarantee dependency order. Solution: implement retry logic or use init containers to avoid CrashLoopBackOff.

- **Correct network identity is critical in K8s**  
  Internal communication must use reachable addresses (e.g., Service DNS, not `localhost`). Kafka `ADVERTISED_LISTENERS` and access to host services (`host.minikube.internal`) highlight that misconfigured endpoints break cross-service connectivity.

- **K8s resource schema & image workflow impact reliability**  
  Misusing fields (e.g., `stringData` in ConfigMap) causes validation failures, while image loading strategies (`minikube image load` vs docker-env) affect deployment reproducibility and dev workflow efficiency.

## Artifacts Built Today

- [x] k8s manifests: `k8s/day-14/*.yaml` — 13 files (4×CM + 2×Secret via kubectl + 4×Deployment + 4×Service + 1×Ingress)
- [x] Memory file: `memory/kubernetes-project.md` — service table, DNS pattern, apply order, 7 failures+fixes
- [x] Updated: `program-standards/day-14-15/DOPs/DOP-01-service-deployment.md` — added 4 confirmed services, fixed stringData→data
- [x] Updated: `program-standards/day-14-15/IRDs/IRD-01-service-deployment.md` v1.1 — full env var classification table

## How I Used Claude Code Today
Used Claude in the full structured pipeline: PM Step → DOP Step → IRD Step.

## Blockers / Questions for Mentor
- None

## Self Score
- Completion: 10/10
- Understanding: 9/10
- Energy: 8.5/10

## One Thing I Learned Today That Surprised Me
nginx resolves ALL upstream hostnames at container startup — not lazily when a request arrives. If even one `proxy_pass` target doesn't exist in DNS, nginx refuses to start entirely..

---

## Tomorrow's Context Block

**Where I am:** Day 14 complete — all 4 project services (hook-gateway, websocket-responder, qna-agent, frontend) Running 1/1 in minikube default namespace. Ingress at 192.168.49.2 tested. memory/kubernetes-project.md written. Kafka + Redis + Milvus + MongoDB running on host (192.168.49.1) reached via docker-compose.

**What's in progress / unfinished:** Day 15 (Helm intro) not started. Redis is on host docker-compose; Day 15 requires installing Redis via Bitnami Helm chart into minikube, updating qna-agent ConfigMap REDIS_URL to the Helm service hostname, and writing memory/helm-basics.md.

**First thing to do tomorrow:** Install Helm, run `helm create myapp` to explore chart structure, add Bitnami repo, write `k8s/day-14/my-redis-values.yaml`, install `bitnami/redis` as release `my-redis`, read NOTES.txt for service hostname, update qna-agent ConfigMap REDIS_URL from `192.168.49.1:6379` to `my-redis-master:6379`, restart qna-agent deployment, verify connection from inside pod.
