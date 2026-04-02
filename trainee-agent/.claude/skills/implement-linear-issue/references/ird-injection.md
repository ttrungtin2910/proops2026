# IRD Injection — How to Load Standards Before Implementing

## The Pattern

Before generating any infrastructure config, Dockerfile, K8s manifest, or pipeline:

1. Fetch the relevant IRD(s) from Notion via `mcp__notion`
2. Extract only the sections that apply to this specific implementation
3. Prepend them to your working context as a **Standards Block**
4. Implement from the Standards Block — not from general DevOps knowledge

## Standards Block Format

```
Standards Block — [ISSUE-ID]
────────────────────────────────────
IRD-006 (Terraform Standards) — Applicable Sections:

NAMING CONVENTION:
  Resource:     [pattern]
  Module:       [pattern]
  Variable:     [pattern]

REQUIRED CONFIG:
  State backend:    [value]
  State key format: [pattern]
  Provider version: [constraint]

ENVIRONMENT VARIABLES:
  dev:  [specific values]
  stag: [specific values]
  prod: [specific values]

ALWAYS:
  - [rule from IRD]
  - [rule from IRD]

NEVER:
  - [anti-pattern from IRD]
────────────────────────────────────
```

## What to Extract (by IRD)

**IRD-001 (Git):** Branch naming pattern, commit format, PR requirements

**IRD-002 (Docker):** Image naming/tagging pattern, multi-stage rules, required build args, NEVER run as root rule

**IRD-003 (K8s):** Namespace naming, required labels, resource limits table, health check requirements, NEVER use `latest` tag rule

**IRD-004 (Helm):** Chart structure, values file naming per env, required annotations

**IRD-005 (AWS):** VPC CIDR ranges, subnet layout, security group naming, required tags (Environment, Project, Owner, ManagedBy), instance naming pattern

**IRD-006 (Terraform):** Naming convention table, state backend config, module structure, variable naming, environment-specific values table

**IRD-007 (CI/CD):** Branch-to-environment mapping table, pipeline stage sequence, secret injection method, quality gate thresholds, promotion rules

**IRD-008 (Code Quality):** Linting tool + config, test coverage minimum, SonarQube gate thresholds

**IRD-009 (Observability):** Log format (JSON fields), metric naming pattern, alert threshold table, dashboard naming

**IRD-010 (Multi-Env):** Environment promotion rules, parity requirements, config override patterns

## When IRD Is Silent

If the IRD doesn't cover a specific decision needed for implementation:

1. Make a reasonable choice
2. Document it explicitly: "IRD-006 doesn't specify X — I used Y because Z"
3. After implementation, create an issue: "Update IRD-006: add standard for X"

**Never silently deviate.** The IRD is the source of truth — if it's incomplete, that's a gap to fix, not a reason to guess.
