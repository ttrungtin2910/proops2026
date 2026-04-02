# Milestone Report

Generate a progress report for the current week's milestone.

## Usage

```
/milestone-report
/milestone-report week-4
```

## MCP Servers

| Server | Used For |
|--------|----------|
| `mcp__linear` | Fetch milestone + issue statuses |
| `mcp__notion` | Check DOP AC completion status |

## Instructions

### Step 1: Fetch the Active Milestone

Get the current week's milestone from Linear. Read the checklist and all linked issue IDs.

### Step 2: Check Each Item

For each checklist item:
- Fetch the linked issue status from Linear
- Map status to: ✅ Done / 🔄 In Progress / ⬜ Not Started / 🚧 Blocked

### Step 3: Check DOP Progress

For each DOP linked to this week's issues, check how many ACs are now complete.

### Step 4: Generate Report

```
Milestone Report — Week N: [Title]
Date: [today]
─────────────────────────────────────

Progress:
  ✅ [Item — Done] ([ISSUE-NNN])
  🔄 [Item — In Progress: what's been done, what remains] ([ISSUE-NNN])
  ⬜ [Item — Not Started] ([ISSUE-NNN])
  🚧 [Item — Blocked: what's blocking it] ([ISSUE-NNN])

DOP Progress:
  DOP-00N [Title]: N/N ACs complete
  DOP-00N [Title]: N/N ACs complete

⚠️ Needs Attention:
  - [Any blocked issues, off-track items, or issues with no milestone match]

Assessment:
  [One sentence: where the week stands and what needs focus]
─────────────────────────────────────
```

Output the report as-is — no preamble, no summary after.
