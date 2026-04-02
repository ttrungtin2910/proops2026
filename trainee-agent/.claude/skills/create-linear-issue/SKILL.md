---
name: create-linear-issue
description: |
  Creates a Linear issue from a task idea, topic completion, or mock project work.
  Links the issue to the relevant DOP and IRDs in Notion.
  Triggers on "create issue", "new ticket", "log task", "break down <issue-id>", or "/create-issue".
---

# Create Linear Issue

You are a **coordinator**. Turn a task idea into a clear, well-structured Linear issue linked to the correct DOP and IRDs.

## MCP Servers

| Server | Used For |
|--------|----------|
| `mcp__linear` | All Linear operations |
| `mcp__notion` | Read DOPs and IRDs for linking |

## Core Rules

1. **Link to DOP and IRDs.** Every issue must reference the DOP it delivers against and the IRDs that govern implementation.
2. **Acceptance criteria must be testable.** Not "Docker works" — "Container starts, responds on port 3000, passes health check."
3. **Confirm before creating.** Always show the full issue for approval before calling Linear.
4. **L is the maximum estimate.** Anything larger — decompose first.

## Issue Types in This Program

| Type | When to Use |
|------|-------------|
| **Task** | Standard implementation work (Terraform, Docker, K8s, CI/CD) |
| **Bug** | Something broken that worked before |
| **Learning** | A study/research spike with a defined output artifact |

## Estimate Scale

| Label | Points | Meaning |
|-------|--------|---------|
| XS | 1 | < 2 hours — isolated, well-understood |
| S | 2 | Half day — clear scope |
| M | 3 | 1–2 days — moderate complexity |
| L | 5 | 3–5 days — multi-component, needs planning |
| > L | — | Decompose into child issues first |

## Flow

### 1. Understand the Request

Classify as `task`, `bug`, or `learning`. Ask **at most 2** clarifying questions. Don't ask what you can infer from the topic.

If the user provides an existing issue ID with decompose intent, follow the **Decompose Path** below.

### 2. Find the Linked DOP

Search Notion for the trainee's DOPs to find which one this issue delivers against:

- ISSUE about containers/K8s → **DOP-001** (Containerization & Orchestration)
- ISSUE about AWS/VPC/EC2/networking → **DOP-002** (AWS Infrastructure)
- ISSUE about CI/CD/pipelines/quality → **DOP-003** (CI/CD Pipeline System)
- ISSUE about monitoring/logging/alerting → **DOP-004** (Observability Stack)
- ISSUE about agent memory/skills/CLAUDE.md → **DOP-005** (My DevOps AI Agent)

### 3. Find Relevant IRDs

Based on the topic, identify which IRDs govern this implementation:

| Topic | Relevant IRDs |
|-------|--------------|
| Git, branching, commits | IRD-001 |
| Docker, containers, images | IRD-002 |
| Kubernetes manifests, Helm | IRD-003, IRD-004 |
| AWS resources, VPC, EC2 | IRD-005 |
| Terraform, state, modules | IRD-006 |
| CI/CD pipelines, GitHub Actions | IRD-007 |
| Code quality, linting, tests | IRD-008 |
| Metrics, logs, dashboards | IRD-009 |
| Multi-environment promotion | IRD-010 |

### 4. Draft the Issue

Compose the issue with:

- **Title** — action-oriented, under 80 chars. "Dockerize TaskFlow API" not "Docker"
- **Description** — context: what needs to be done and why, what DOP this delivers
- **Acceptance Criteria** — testable checklist. Each item is binary: done or not done.
- **Linked DOP** — `[DOP-00N: Title](notion-url)`
- **Linked IRDs** — `[IRD-00N: Topic](notion-url)` for each relevant standard
- **Estimate** — from the scale above
- **Labels** — `mock-project` or `agent-build` or `learning`

**AC writing rules:**
- Start with a verb: "Container starts...", "Pipeline runs...", "Terraform applies..."
- Include the verification method: "...verified by `docker ps`", "...pipeline passes in < 5 min"
- No vague criteria: not "works correctly", not "looks good"

### 5. Confirm and Create

Present to the user:
```
Issue Preview
─────────────────────────────
Title:      [title]
Type:       [task/bug/learning]
Estimate:   [XS/S/M/L]
Labels:     [labels]
Linked DOP: [DOP-00N]
Linked IRDs: [IRD-00N, IRD-00N]

Description:
[description]

Acceptance Criteria:
- [ ] [AC 1]
- [ ] [AC 2]
─────────────────────────────
Proceed? (yes / adjust: ...)
```

Once approved, create via `mcp__linear` and return the issue ID and URL.

## Decompose Path

When asked to break down an existing issue:

1. Fetch the issue from Linear
2. Split into 2–4 child issues, each ≤ L estimate
3. Each child: clear title, its own ACs, inherits parent's DOP/IRD links
4. Present all children for approval before creating
5. Create in parallel, link each to the parent issue
