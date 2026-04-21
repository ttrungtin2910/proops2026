---
name: Container Orchestration
description: Five orchestration problems, what each orchestrator solves, Swarm lab observations, Compose vs Swarm vs K8s comparison
type: project
---

## The Five Orchestration Problems

**Scheduling** — Deciding which server runs which container. Without an orchestrator: SSH into each machine manually, guess available resources, containers get OOM-killed when placed on overloaded nodes. Orchestrator: scheduler knows CPU/RAM per node, places containers automatically.

**Health Monitoring & Recovery** — Detecting and replacing failed containers. Without an orchestrator: container dies, stays dead until someone notices and restarts it manually. Orchestrator: continuously reconciles desired state vs actual state, recreates failed containers within seconds.

**Service Discovery** — Containers finding each other when IPs change. Without an orchestrator: hardcoded IPs in `.env` break when containers restart on new IPs. Orchestrator: internal DNS maps service names to current IPs automatically — `api` calls `db:5432` regardless of where `db` is running.

**Rolling Deployments** — Updating services without downtime. Without an orchestrator: `docker compose down` then `up` = complete downtime window; any bug hits all users immediately. Orchestrator: replaces replicas one at a time, keeps at least one old replica running, pauses rollout on failure.

**Scaling** — Adding replicas under load. Without an orchestrator: SSH each machine, edit compose files, restart manually — slow and error-prone with no automation. Orchestrator: one command adds replicas across available nodes, load balancer picks them up automatically.

---

## What I Observed Today (Swarm Lab)

Ran `docker swarm init` → `docker service create --replicas 2 nginx` → `docker kill <container-id>`. Swarm detected the killed container within 1–2 seconds and created a replacement task automatically. `docker service ps web` showed the failed task with `CURRENT STATE = Failed` and a new task with `DESIRED STATE = Running / CURRENT STATE = Running` — the reconcile loop in action.

---

## Compose vs Swarm vs Kubernetes

| Problem | Docker Compose | Docker Swarm | Kubernetes |
|---|---|---|---|
| Scheduling | Manual (you choose the machine) | Basic (fits to available node) | Advanced (affinity, taints, resource requests) |
| Health monitoring | No auto-recovery | Auto-restarts failed tasks | Auto-restarts + readiness/liveness probes |
| Service discovery | Manual (`.env` IPs) | Built-in DNS by service name | Built-in DNS + Services + Endpoints |
| Rolling deployments | No (full downtime) | Yes (one replica at a time) | Yes (configurable strategy, canary possible) |
| Scaling | Manual (`docker compose up --scale`) | One command, multi-node | One command + HPA (auto on CPU/memory) |
| Multi-node clusters | No | Yes (basic) | Yes (production-grade) |
| Config management | `.env` files | Secrets + Configs objects | ConfigMaps + Secrets |
| Ecosystem / tooling | Minimal | Minimal | Helm, Argo, Kustomize, full CNCF stack |

---

## Why Kubernetes Next

Swarm covers the five problems but lacks production requirements: no autoscaling on metrics (HPA), no fine-grained RBAC, no declarative config management (ConfigMaps/Secrets), no ecosystem for GitOps or observability — Kubernetes provides all of these and is the industry standard for production workloads.
