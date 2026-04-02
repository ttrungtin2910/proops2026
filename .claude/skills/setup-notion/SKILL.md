# Skill: /setup-notion

Triggers on: "setup notion", "initialize notion", "create my notion workspace", `/setup-notion`

---

## What this skill does

Creates your complete ProOps2026 doc-system structure in your own Notion account.
Run this once on Day 1 after Notion MCP is connected.

Creates:
- Root page: `ProOps2026 — [Your Name]`
- Sub-page: `📋 Training Spec` (pre-filled template)
- Sub-page: `📦 DOPs` (DOP-001 to DOP-005 tracker)
- Sub-page: `📐 IRDs` (IRD-001 to IRD-010 tracker)

After creation: prints share instructions so you can give your trainer read access.

---

## Instructions for Claude

When this skill is triggered:

### Step 1 — Get trainee name

Read `CLAUDE.md` in the current project. Extract the trainee name from the Identity & Role section.
If not found, ask: "What is your name? I'll use it for the Notion page titles."

### Step 2 — Create root page

Use `mcp__notion__notion-create-pages` to create a page with:
- Title: `ProOps2026 — [Name]`
- Content: brief description block — "ProOps2026 training workspace for [Name]. Contains Training Spec, DOPs, and IRDs."

Store the page ID as `ROOT_PAGE_ID`.

### Step 3 — Create Training Spec sub-page

Create a child page under `ROOT_PAGE_ID` with:
- Title: `📋 Training Spec`
- Content: the full template below (render as Notion blocks)

**Training Spec template content:**

```
What is this?
This is your standing Context (C) in the C.R.A.F.T. prompting framework.
Claude reads this automatically at the start of every session via MCP.
Update Current Position and What's In Progress every single day.

---

IDENTITY & BACKGROUND
Name: [fill in]
Role before training: [Junior Dev / Senior Dev / IT Helpdesk / QA / DevOps]
Strongest area: [fill in]
Weakest area: [fill in]
Why I'm here: [fill in]

MY STACK & ENVIRONMENT
OS: Ubuntu 22.04
Cloud: [AWS / GCP / Azure]
Languages: [fill in]
Tools used before: [fill in]
Agent repo: [GitHub repo URL]

CURRENT POSITION
Week: [fill in]
Day: [fill in]
Today's topic: [fill in]
Active Linear issue: [fill in]

GOALS THIS WEEK
1. [fill in]
2. [fill in]
3. [fill in]

DECISIONS MADE
[Date] | [Area] | [Decision] | [Why]

WHAT'S IN PROGRESS
[Updated from Daily Log — Tomorrow's Context Block]

WHAT'S NEXT
[fill in]
```

### Step 4 — Create DOPs sub-page

Create a child page under `ROOT_PAGE_ID` with:
- Title: `📦 DOPs`
- Content:

```
Definition of Product pages — what success looks like for each product area.
Written by you at the start of each area. DOP-000 is instructor-provided (read it in Program Standards).

Status tracker:
DOP-000 | Working Model Setup       | Instructor-provided | Read on Day 1 | Required: Day 1
DOP-001 | Containerization          | Not started         | —             | Required: before Day 7
DOP-002 | AWS Infrastructure        | Not started         | —             | Required: before Day 6
DOP-003 | CI/CD                     | Not started         | —             | Required: before Day 22
DOP-004 | Observability             | Not started         | —             | Required: before Day 31
DOP-005 | My AI Agent               | Not started         | —             | Required: end of Day 5 (draft), Day 39 (complete)
```

### Step 5 — Create IRDs sub-page

Create a child page under `ROOT_PAGE_ID` with:
- Title: `📐 IRDs`
- Content:

```
Implement Requirements Definition pages — settled standards your agent follows before implementing.
Written by you after studying a topic, before building with it.

Status tracker:
IRD-000 | Context Document Standards | Instructor-provided | Read on Day 1 | Required: Day 1
IRD-001 | Git Standards              | Not started         | —             | Required: end of Day 3
IRD-002 | Docker Standards           | Not started         | —             | Required: before Day 7
IRD-003 | Kubernetes Standards       | Not started         | —             | Required: before Day 12
IRD-004 | Helm Standards             | Not started         | —             | Required: before Day 14
IRD-005 | AWS Infra Standards        | Not started         | —             | Required: before Day 6
IRD-006 | Terraform Standards        | Not started         | —             | Required: before Day 19
IRD-007 | CI/CD Standards            | Not started         | —             | Required: before Day 22
IRD-008 | Code Quality Standards     | Not started         | —             | Required: before Day 25
IRD-009 | Observability Standards    | Not started         | —             | Required: before Day 31
IRD-010 | Multi-Env Standards        | Not started         | —             | Required: before Day 29
```

### Step 6 — Report output

After all pages are created, output a summary:

```
✓ Notion workspace created for [Name]

Pages created:
  ProOps2026 — [Name]  (root)
    ├── 📋 Training Spec
    ├── 📦 DOPs
    └── 📐 IRDs

Next steps:
1. Open the root page in Notion: [link if available from MCP response]
2. Share it with your trainer:
   - Open the page → click "Share" (top right)
   - Click "Invite"
   - Enter trainer's email: [TRAINER_EMAIL]
   - Set permission: "Can view"
   - Click "Invite"
3. Fill in your Training Spec now — start with Identity & Background and My Stack.
4. Connect the root page to your Notion integration:
   - Open the page → "..." → Connections → select "ProOps2026 Claude" → Confirm
   - Do the same for each sub-page (Training Spec, DOPs, IRDs)
```

---

## Error handling

- If Notion MCP is not connected: "Run `/mcp` — Notion should appear in the list. If not, follow `templates/mcp-setup.md` first."
- If page creation fails: try creating root page manually in Notion, then rerun the skill with the root page ID provided
- If name not found in CLAUDE.md: ask for name before proceeding
