---
name: create-spec
description: |
  Creates an infrastructure or system spec — a snapshot of what was built, how it connects,
  and what the agent needs to know to work with it next session without re-exploring.
  Triggers on "create spec", "write spec", "document this", "/create-spec".
---

# Create Spec

You are a **spec writer**. Create a spec that lets the agent work with a system next session without re-reading every file.

A spec answers: **What was built, how does it connect, and what are the non-obvious constraints?**

Specs are NOT the same as IRDs:
- **IRD** = standards and decisions made *before* building (forward-looking)
- **Spec** = description of what was actually built (backward-looking, present state)

## When to Create a Spec

After completing a significant implementation:
- A Terraform module that provisions multiple resources
- A Kubernetes cluster configuration with multiple components
- A CI/CD pipeline with multiple stages
- An observability stack with multiple tools connected

## Flow

### 1. Explore What Was Built

Examine:
- What files/resources were created
- How the components connect
- What the non-obvious constraints are (the things that would trip up the next agent session)
- What commands are needed to operate it

### 2. Draft the Spec

```markdown
# [System / Component Name]

**Built from:** [ISSUE-NNN], [ISSUE-NNN]
**IRD Governing:** [IRD-00N: Title]
**Last updated:** [date]

## What This Is

[2–3 sentences: what this system does and why it exists]

## Architecture

[Key facts about how it's structured — components, connections, what talks to what]
- [Fact]
- [Fact]
- [Fact]
(3–7 bullets. How things connect, not what they are.)

## Key Configuration

| Setting | Value | Where Defined |
|---------|-------|---------------|
| [param] | [value] | [file / env var / AWS console] |

## How to Operate

| Action | Command |
|--------|---------|
| [common operation] | `[command]` |
| [common operation] | `[command]` |

## Non-Obvious Constraints

- [What can't be done and why]
- [Known failure modes with workarounds]
- [Things that look wrong but are intentional]

## Files / Resources

| File / Resource | Purpose |
|----------------|---------|
| `[path]` | [one-line responsibility] |
| `[aws-resource-name]` | [one-line responsibility] |

## IRD Compliance Notes

| IRD | Compliance | Notes |
|-----|-----------|-------|
| [IRD-00N] | ✅ Followed | — |
| [IRD-00N] | ⚠️ Diverged | [what and why] |
```

### 3. Show and Write

Show draft to trainee. Once approved, write to `specs/[category]/[name].md`.

**Spec categories:**
```
specs/
  infrastructure/   ← VPC, EC2, networking specs
  containers/       ← Docker, K8s, Helm specs
  pipelines/        ← CI/CD pipeline specs
  observability/    ← monitoring stack specs
  agent/            ← agent architecture specs
```

## Writing Rules

1. **Agent audience** — agents know Terraform, Docker, K8s, Linux. Don't explain standard patterns.
2. **Present tense only** — how it works now. No history, no "we decided to."
3. **Constraints first** — what CAN'T be done is more valuable than what CAN.
4. **50–150 lines** — if longer, the component needs splitting into two specs.
5. **No code blocks over 10 lines** — link to the file instead.
