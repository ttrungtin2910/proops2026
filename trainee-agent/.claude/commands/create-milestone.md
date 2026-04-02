# Create Weekly Milestone

Create a weekly milestone in Linear — a focused goal with 5–7 outcome-based checklist items.

## Usage

```
/create-milestone [week-number] [short-desc]
```

### Examples
```
/create-milestone
/create-milestone 2 "Docker + First Mock Project Issue"
/create-milestone 4 "AWS Infrastructure + Terraform"
```

## MCP Server

All Linear operations use `mcp__linear`.

## Instructions

### Step 1: Determine the Week

If `week-number` is provided, use it. Otherwise, calculate from today's date against the program start date (Apr 1, 2026).

Week boundaries: Monday (start) → Friday (end). Working days only.

### Step 2: Gather Issue Context

Fetch open Linear issues. Group by topic. Identify:
- Issues that are blocking or foundational (list first)
- Issues already in progress (flag as carry-over if from last week)
- Learning/study issues (flag with `[Study]`)

### Step 3: Draft the Milestone

**Title format:** `Week N — [short-desc]`
Example: `Week 4 — AWS Infrastructure + Terraform`

**Description:**
```markdown
## Goal

[1–2 sentences: what this week delivers and why it matters for the DevOps program.]

## Checklist

- [ ] [Outcome — not task. "Docker memory file complete" not "write docker.md"] ([ISSUE-NNN])
- [ ] [Outcome] ([ISSUE-NNN])
- [ ] **[Study]** [Topic studied with artifact produced] ([ISSUE-NNN])
- [ ] [Mock project milestone if applicable]
```

**Checklist rules:**
- 5–7 items. Each = one shippable outcome.
- Write outcomes ("X is done"), not tasks ("implement X").
- Include Linear issue ID in parentheses.
- `[Study]` prefix for learning/research issues.
- `[Carry-over]` prefix for issues rolling from last week.
- `- [x]` for anything already Done.

### Step 4: Present and Confirm

Show the milestone preview. Wait for approval. Once confirmed, create via `mcp__linear`.

Return milestone title and confirm creation.
