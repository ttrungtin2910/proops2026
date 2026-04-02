---
name: close-linear-issue
description: |
  Closes a Linear issue after implementation is verified.
  Checks all ACs, posts implementation notes, marks Done.
  Triggers on "close ISSUE-NNN", "done with ISSUE-NNN", "ship ISSUE-NNN", or "/close-issue".
---

# Close Linear Issue

You are a **coordinator**. Verify the work is complete, document what was built, and close cleanly.

## MCP Servers

| Server | Used For |
|--------|----------|
| `mcp__linear` | Read issue, check ACs, post notes, transition to Done |
| `mcp__notion` | Update DOP acceptance criteria if this issue completed a DOP goal |

## Core Rules

1. **Never close with unchecked ACs.** If an AC is not met, either fix it or explicitly agree with the trainee to descope it (update the issue).
2. **Always post implementation notes.** The notes are the record of what was actually built — they feed into future IRD updates and the Handover Doc.
3. **If an IRD was violated or extended during implementation** — flag it. An IRD update issue must be created before closing.

## Flow

### 1. Fetch and Review

Get the issue from Linear. Read:
- All ACs — which are checked, which are not
- Any comments — especially clarifying Q&A or scope changes
- Estimate vs actual effort (note if significantly off)

### 2. AC Verification

For each unchecked AC, ask the trainee: "Is this done? If so, confirm how you verified it."

Do not auto-check ACs. The trainee must confirm each one.

If an AC is genuinely descoped (decided not to do it): update the issue description to mark it `~~strikethrough~~ — descoped: [reason]` before closing.

### 3. IRD Compliance Check

Ask: "Did your implementation follow all the relevant IRDs?"

If the trainee diverged from an IRD (different naming, different pattern, different config):
- Document the divergence in the implementation notes
- Create a new issue: "Update IRD-00N to reflect [what changed]"
- This issue must exist before the original issue can be closed

### 4. Draft Implementation Notes

Write concise implementation notes covering:

```markdown
## Implementation Notes — [ISSUE-ID] — [Date]

### What Was Built
[2–3 sentences: what exists now that didn't before]

### Key Decisions Made
[Decisions made during implementation that go beyond what the IRD specified.
 If you followed the IRD exactly, say so.]

### IRD Compliance
[IRD-00N: followed / IRD-00N: diverged — [explain]]

### What the Next Session Needs to Know
[Anything about state, partially done work, gotchas discovered]

### Artifacts Created
| File/Resource | Type | Location |
|---------------|------|----------|
| [name] | [Terraform/Dockerfile/K8s manifest/etc.] | [path] |
```

Show the notes to the trainee for approval before posting.

### 5. Post and Close

Once notes are approved:
1. Post implementation notes as a comment on the Linear issue
2. Check all verified ACs on the issue
3. Transition issue status to **Done**
4. If this issue completed a DOP acceptance criterion — update the DOP in Notion (check the AC)

Report: issue closed, notes posted, any follow-up issues created.
