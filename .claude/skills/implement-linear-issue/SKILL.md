---
name: implement-linear-issue
description: |
  Implements a Linear issue end-to-end: reads the issue, loads the governing DOP and IRDs from Notion,
  plans the implementation, executes, and updates Linear.
  Triggers on "implement ISSUE-NNN", "work on ISSUE-NNN", "ISSUE-NNN", or "/implement-issue".
---

# Implement Linear Issue

You are a **coordinator**. Before writing a single line of config or code, you read what has already been decided.

**The contract:** DOPs define *what*. IRDs define *how*. Linear defines *done-when*. You implement from this — not from general knowledge.

## MCP Servers

| Server | Used For |
|--------|----------|
| `mcp__linear` | Fetch issue, update status, post comments, check ACs |
| `mcp__notion` | Read DOP and IRDs that govern this issue |

## Autonomy

Do not ask permission for non-destructive work. Only confirm:
- The implementation plan (before execution on M/L issues)
- Scope changes discovered during implementation
- Final status before moving to Done

## Setup — Do These Steps Exactly

### Step 1: Fetch the Issue

Get from Linear: title, description, ACs, estimate, status, labels, linked DOP URL, linked IRD URLs.

Read all comments in chronological order — latest takes precedence over description if they conflict.

### Step 2: Guard on Status

- **Done / Cancelled** → Stop. Tell the trainee. Do not proceed.
- **In Progress** → Continue from where it was left off.
- **To Do** → Move to In Progress before starting.

### Step 3: Load the DOP

Fetch the linked DOP from Notion. Read:
- The **Objective** — the overall goal this issue contributes to
- The **Acceptance Criteria table** — find the row this issue maps to
- The **Scope** — what is explicitly in/out of scope
- The **Linked IRDs** — which standards apply

If no DOP is linked in the issue, infer from context and tell the trainee which DOP you're using.

### Step 4: Load the Relevant IRDs

Fetch each relevant IRD from Notion. Read the full **Decisions** and **Standards the Agent Must Follow** sections.

See [ird-injection.md](references/ird-injection.md) for how to structure IRD context before implementation.

### Step 5: Clarifying Questions

Before touching any files, review for:
- Unclear or conflicting requirements
- Missing values the IRD doesn't cover (e.g. specific IP ranges, instance sizes)
- Scope that could be interpreted multiple ways

Compile a numbered list. Post resolved Q&A as a Linear comment. Update issue description with answers.

**Do not proceed until all ambiguities are resolved.**

### Step 6: Plan

See [planning-flow.md](references/planning-flow.md) for planning rules.

- **XS/S** → implement directly, no plan needed
- **M/L** → write a plan, present for approval, post approved plan to Linear as a comment, then execute

Plan format:
```
Implementation Plan — [ISSUE-ID]

Governing standards:
  - DOP-00N: [which section applies]
  - IRD-00N: [which decisions apply]
  - IRD-00N: [which decisions apply]

Steps:
1. [What I'll do — concrete action]
2. [What I'll do]
3. [Verification: how I'll confirm each AC]

Risks:
- [Anything that could go wrong and how I'll handle it]
```

### Step 7: Implement

Follow the IRD standards **exactly**. Do not improvise naming, patterns, or config values — they are already decided.

See [devops-patterns.md](references/devops-patterns.md) for common DevOps implementation patterns.

After completing each AC: check it off on the Linear issue via `mcp__linear`.

### Step 8: Verify

For each AC in the issue, confirm:
- What command or check was run
- What the output was
- Whether it passes

### Step 9: Complete

1. Confirm all ACs are checked on Linear
2. Draft implementation notes — see [impl-notes.md](references/impl-notes.md) for format
3. Present notes to trainee for approval
4. Post approved notes as a Linear comment
5. Move issue to **In Review** (not Done — trainee reviews before closing)
6. If implementation required a decision not covered by any IRD — create an issue to add it: "Update IRD-00N: [what was decided"

Report: all ACs checked, notes posted, issue in review, any IRD update issues created.
