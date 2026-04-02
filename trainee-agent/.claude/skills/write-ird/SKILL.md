---
name: write-ird
description: |
  Creates a new IRD (Implement Requirements Definition) page in Notion.
  An IRD records settled design decisions and standards the agent follows during implementation.
  Triggers on "write IRD", "create IRD", "define standards for [topic]", "/write-ird".
---

# Write IRD

You are a **standards architect**. Help the trainee define the implementation rules their agent will follow — before the agent writes a single line of config.

An IRD answers: **How exactly will this be implemented? What are the standards, naming conventions, and non-negotiable rules?**

## MCP Server

All Notion operations use `mcp__notion`.

## IRDs in This Program

| IRD | Topic | Created |
|-----|-------|---------|
| IRD-001 | Git Standards | Week 1 |
| IRD-002 | Docker & Container Standards | Week 2 |
| IRD-003 | Kubernetes Standards | Week 3 |
| IRD-004 | Helm Standards | Week 3 |
| IRD-005 | AWS Infrastructure Standards | Week 4 |
| IRD-006 | Terraform Standards | Week 4 |
| IRD-007 | CI/CD Pipeline Standards | Week 5–6 |
| IRD-008 | Code Quality Standards | Week 5–6 |
| IRD-009 | Observability Standards | Week 7 |
| IRD-010 | Multi-Environment Standards | Week 6–8 |

## Core Rules

1. **Decisions are settled.** An IRD is not a discussion doc — it records what has been decided. The agent implements from the IRD, not from general knowledge.
2. **Tables over prose.** Naming conventions, config values, required flags — always in tables. Tables are agent-readable. Prose hides assumptions.
3. **One home per fact.** If a standard appears in two IRDs, one is wrong — or will drift. Keep it in the most specific IRD.
4. **Show draft before creating.** Trainee approves all decisions before the IRD is written.
5. **IRDs evolve.** When you learn something new that changes the standard — update the IRD, don't append notes.

## IRD Structure by Topic

### For Infrastructure IRDs (IRD-005, IRD-006)

Focus on: naming conventions, required tags/labels, configuration tables, environment-specific values, state management.

### For Pipeline IRDs (IRD-007)

Focus on: branch-to-environment mapping, pipeline stage sequence, secret injection pattern, quality gates, promotion rules.

### For Container/Orchestration IRDs (IRD-002, IRD-003, IRD-004)

Focus on: image naming/tagging, resource limits, required labels, health check patterns, multi-stage build rules.

### For Observability IRDs (IRD-009)

Focus on: log format, metric naming convention, alert threshold table, dashboard naming.

## Flow

### 1. Understand the Topic

Ask:
- Which IRD area is this? (use the table above)
- What standard are they defining? (naming? config? pattern?)
- What have they learned so far that informs this standard?
- What environment does this run in? (dev/stag/prod)

### 2. Draft the IRD

Use this structure — adapt sections to the topic:

```markdown
# IRD-00N: [Topic] Standards

| Property | Value |
|----------|-------|
| **ID** | IRD-00N |
| **Status** | Approved |
| **Type** | Standard |
| **Topic** | [Git / Docker / K8s / Helm / AWS / Terraform / CI/CD / Quality / Observability / Multi-Env] |
| **Week** | Week N |
| **Owner** | [Trainee name] |
| **Version** | 1.0 |

---

## Decisions

These are settled. The agent implements from these decisions — it does not re-decide them.

1. [Decision statement — one fact, one sentence]
2. [Decision statement]
3. [Decision statement]

---

## Naming Convention

| Resource | Pattern | Example |
|----------|---------|---------|
| [Resource type] | [pattern with variables] | [concrete example] |

---

## Required Configuration

| Setting | Value | Applies To |
|---------|-------|-----------|
| [config key] | [value or rule] | [all / dev only / prod only] |

---

## Environment-Specific Values

| Parameter | dev | stag | prod |
|-----------|-----|------|------|
| [param] | [val] | [val] | [val] |

---

## Standards the Agent Must Follow

When generating any [Terraform/Dockerfile/K8s manifest/pipeline config] for this trainee:

- ALWAYS: [rule]
- ALWAYS: [rule]
- NEVER: [anti-pattern]
- NEVER: [anti-pattern]

---

## Linked DOPs

| DOP | How This IRD Governs It |
|-----|------------------------|
| [DOP-00N] | [which section / which resources] |

---

## Version History

| Version | Date | Change |
|---------|------|--------|
| 1.0 | [date] | Initial standard |
```

### 3. Confirm and Create in Notion

Show the full draft. Once approved:
1. Create the page in Notion under the trainee's `IRDs/` section
2. Return the Notion URL
3. Remind the trainee: "Before implementing anything in this area, paste the relevant sections of this IRD into your prompt — or reference it explicitly so the agent reads it via MCP."
