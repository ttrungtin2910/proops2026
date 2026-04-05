---
name: Software Architecture Patterns
description: Five application architecture patterns with DevOps implications — pipeline, scaling, observability, rollback
type: user
---

# Five Application Architecture Patterns: DevOps Implications

## 1. Monolith

**What it is:** One codebase, one deployable artifact, one running process that owns all business logic and data.

**Pipeline complexity:** Single pipeline, one build, one deploy step, one artifact version to track. Integration tests are straightforward — everything is in-process. Build times grow linearly with codebase size.

**Scaling model:** Vertical first (bigger instance), then horizontal by running identical copies behind a load balancer. Horizontal scaling requires stateless app (sessions in Redis, not in-memory). Cannot scale one domain without scaling all of them.

**Observability requirements:** Single log stream, single metrics endpoint, single trace context. One structured log line per request reconstructs what happened. Stack trace tells the complete story — no distributed tracing needed.

**Rollback strategy:** Redeploy previous artifact. One command, deterministic, safe. Only complication: database migrations must be backward-compatible with the previous app version.

---

## 2. Microservices

**What it is:** Business domains split into independently deployable services, each owning its own data store and communicating over the network.

**Pipeline complexity:** One pipeline per service, independently versioned. Requires contract testing (Pact) between services to catch API breaking changes. Deploy order matters — API providers deploy before consumers. N services = N pipelines to maintain.

**Scaling model:** Independent horizontal scaling per service. Requires Kubernetes in practice. Each service needs its own resource limits, HPA rules, and pod disruption budgets.

**Observability requirements:** Distributed tracing mandatory — W3C `traceparent` must propagate across every service boundary. Correlation ID ties logs, metrics, and spans together. Requires centralized log aggregation, a tracing backend (Jaeger/Tempo), and per-service SLOs.

**Rollback strategy:** Roll back the affected service independently — only safe if every deploy is backward-compatible with adjacent service versions (enforced by contract tests). Breaking API change already in production = roll forward, not back.

---

## 3. Event-Driven

**What it is:** Services communicate exclusively by publishing and consuming events through a broker (Kafka, SQS, EventBridge) — no direct synchronous calls between producers and consumers.

**Pipeline complexity:** Pipeline must validate event schema compatibility before every producer deploy (Confluent Schema Registry / AWS Glue). Schema changes are breaking changes for all consumers. Consumer pipelines must test against the actual event format they will receive.

**Scaling model:** Consumers scale based on queue depth / consumer lag, not CPU. Kafka requires partition count planning at topic creation — cannot easily repartition in production.

**Observability requirements:** Trace context must be embedded in the event payload and extracted by the consumer — severed by default at the queue boundary. Consumer lag is the primary health metric, not CPU. DLQs (dead letter queues) are mandatory — failed messages must land somewhere inspectable.

**Rollback strategy:** Rolling back a consumer is safe. Rolling back a producer is dangerous if the old version emits a schema that deployed consumers don't handle. Events already published cannot be unpublished — compensate with a correcting event or replay from a corrected offset.

---

## 4. Serverless

**What it is:** Stateless functions (AWS Lambda, Cloud Functions) that execute on-demand; cloud provider manages all infrastructure, scaling, and availability.

**Pipeline complexity:** No Dockerfile or K8s manifests — but IAM roles, env vars, API Gateway config, and packaging all live in the pipeline. IaC (SAM, Serverless Framework, Terraform) is not optional. Cold start duration must be a CI performance gate.

**Scaling model:** Automatic, near-instant, scales to zero. Risk: AWS Lambda regional concurrency limit (default 1000) is shared across all functions — one spike can throttle unrelated functions. Reserved concurrency per function is a deploy-time config decision.

**Observability requirements:** Structured logging with correlation ID on every invocation is required — execution is ephemeral. Cold start duration, init time, and memory ceiling are function-specific KPIs. X-Ray/tracing must be explicitly enabled per function in deployment config (off by default).

**Rollback strategy:** Lambda versions + aliases enable instant traffic shifting — shift alias from v13 back to v12 in seconds with zero redeploy. Only works if pipeline manages aliases explicitly. Deploying directly to `$LATEST` (the default) means no prior versions exist to roll back to.

---

## 5. Service Mesh (Sidecar Proxy Pattern)

**What it is:** Network communication handled by a sidecar proxy (Envoy via Istio/Linkerd) injected into every pod, moving mTLS, retries, circuit breaking, and observability out of application code into infrastructure.

**Pipeline complexity:** Every deploy must verify sidecar injection before routing traffic — a pod without sidecar is silently unreachable under mTLS. Canary traffic splitting is configured as `VirtualService` + `DestinationRule` manifests — traffic weight is infrastructure code, not application code.

**Scaling model:** Sidecar adds ~50–100m CPU and ~50–100Mi memory per pod at idle. At 1000 pods = 1000 sidecars = significant cluster overhead. Resource requests and node sizing must account for this. Control plane (Istiod) is itself critical infrastructure requiring its own monitoring.

**Observability requirements:** Mesh generates golden signal metrics (rate, error rate, latency) for every service-to-service call automatically — no app instrumentation needed. New service gets L7 traffic metrics for free on first deploy.

**Rollback strategy:** Shift 100% of traffic back to the previous `DestinationRule` subset instantly — no redeploy needed. New version pods remain running but receive zero traffic, allowing inspection before deletion. Requires pipeline to manage `VirtualService` weights in deploy/rollback automation.

---

## Quick Reference

| Pattern | Pipeline | Scaling | Observability | Rollback |
|---|---|---|---|---|
| Monolith | Single pipeline | Vertical → horizontal (stateless) | Single log+trace | Redeploy artifact |
| Microservices | Per-service + contract tests | Independent per service (K8s) | Distributed tracing required | Per-service (backward-compat required) |
| Event-driven | Schema validation gate | Consumer lag-based | Trace in payload, DLQ mandatory | Compensating events |
| Serverless | IaC required, cold start gate | Auto (watch concurrency limits) | Structured logs, X-Ray opt-in | Alias traffic shift |
| Service mesh | Sidecar injection gate | Account sidecar overhead | Golden signals free, control plane monitored | VirtualService traffic shift |
