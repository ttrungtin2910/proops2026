# Daily Log — Tin (Trần Trung Tín) — Day 2 — 2026-04-06

## Today's Assignment
- [x] Review Training Spec in Notion
- [x] Study software architecture patterns (DevOps lens)
- [x] Write memory/software-architecture.md

## Completed
- [x] Read Training Spec from Notion — confirmed Week 1 goals and open items
- [x] Studied 5 architecture patterns with full DevOps implications: monolith, microservices, event-driven, serverless, service mesh
- [x] Written `memory/software-architecture.md` — pattern recognition reference with quick-reference table
- [x] Practiced incident response reasoning: DB at 95% CPU diagnostic framework (3 questions before action)
- [x] Studied distributed systems failure modes: monolith → microservices, message queue vs direct HTTP
- [x] Studied CI/CD concerns specific to microservices: deploy order, service discovery, distributed tracing, independent rollback

## Not Completed
| Item | Reason | Time Spent |
|---|---|---|
| daily-logs/day-02.md | Created end of session | — |
| IRD-001 published to Notion | Carried over to Day 3 | 0hr |
| First real Linear training issue | Carried over to Day 3 | 0hr |

## Extra Things Explored
- Traced a full "add to cart" HTTP request: browser → DNS → TCP → TLS → LB → Node.js → PostgreSQL, with failure modes at each step
- Explored what breaks at 1000 orders/minute with direct HTTP vs message queue
- Discussed pricing service slowness: 4 concrete scenarios (degraded UX → cascade → partial write → circuit breaker)

## Artifacts Built Today
- [x] `memory/software-architecture.md` — 5 architecture patterns, DevOps implications, quick-reference table
- [x] `daily-briefs/day-02.html` — session brief committed

## How I Used Claude Code Today
Used Claude Code as a Senior DevOps Engineer to work through distributed systems concepts hands-on — request tracing, failure mode analysis, architecture pattern recognition. Each topic was explored with concrete scenarios (1000 orders/minute, 95% DB CPU, pricing service slowness) rather than abstract theory. The architecture patterns session produced a direct memory file artifact that will be referenced in future sessions.

## Blockers / Questions for Mentor
- Do I need a real domain name for K8s ingress exercises in Week 3, or will minikube + local DNS cover it?
- IRD-001 (Git Standards) was drafted Day 1 — confirm: publish to Notion as-is or review first?

## Self Score
- Completion: 8/10
- Understanding: 9/10
- Energy: 8/10

## One Thing I Learned Today That Surprised Me
The message queue is not a performance optimization — it is a durability and decoupling contract. Before this session I thought queues were about speed. The real value is that messages survive service restarts, deploys, and crashes. A direct HTTP call has no third state — it either responds or errors. A queue introduces durable storage as the middleman, which changes the entire failure model.

---

## Tomorrow's Context Block

**Where I am:** End of Day 2, Week 1 — software-architecture.md written covering 5 patterns (monolith, microservices, event-driven, serverless, service mesh) with full DevOps implications per pattern: pipeline complexity, scaling model, observability requirements, and rollback strategy.

**What to do tomorrow (Day 3):** Publish IRD-001 to Notion, create first real Linear training issue via /create-linear-issue, and open a feat/w1-* branch following IRD-001 commit standards.

**Open question:** Do I need a real domain name for K8s ingress exercises in Week 3, or will minikube + local DNS cover it?
