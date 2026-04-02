# Planning Flow

## When to Plan

| Estimate | Action |
|----------|--------|
| XS / S | Implement directly — no plan needed |
| M / L | Write plan → present → get approval → post to Linear → execute |

## Plan Structure

```
Implementation Plan — [ISSUE-ID]: [Title]
Date: [today]

Governing Standards:
  DOP-00N [Title] — [which section applies]
  IRD-00N [Title] — [which decisions apply]
  IRD-00N [Title] — [which decisions apply]

Steps:
  1. [Concrete action — what file/resource/command]
  2. [Concrete action]
  3. [Concrete action]
  ...

Verification:
  AC 1: "[AC text]" — verified by [command/check]
  AC 2: "[AC text]" — verified by [command/check]

Risks:
  - [Risk and mitigation]
  - [Risk and mitigation]

IRD Gaps (decisions the IRD doesn't cover):
  - [If any — what I'll decide and why]
```

## Plan Quality Rules

1. **Each step references a file or resource** — not "configure Terraform" but "create `modules/vpc/main.tf` with..."
2. **Each AC has a verification method** — the exact command or check that proves it
3. **IRD gaps are explicit** — if the IRD doesn't specify something, say so up front
4. **No steps that are "then figure it out"** — if a step is unclear, it's a clarifying question, not a plan step

## After Approval

Post the approved plan as a Linear comment before executing:

```
## Implementation Plan — [Date]

[paste the approved plan]

Status: Approved — proceeding with implementation
```

This creates a record. If the trainee reviews the issue later, they can see what was planned vs what was actually built (from the impl notes).
