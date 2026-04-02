# Implementation Notes Format

Implementation notes are the lowest layer of the documentation stack.
They record what was actually built — feeding into future IRD updates and the trainee's memory files.

## Format

```markdown
## Implementation Notes — [ISSUE-ID]: [Title] — [Date]

### What Was Built
[2–3 sentences: what exists now that didn't before. Concrete — not "implemented Docker" but
 "Created multi-stage Dockerfile for TaskFlow API. Image size: 185MB (down from 1.2GB with build stage).
  Runs as non-root user `appuser` per IRD-002."]

### IRD Compliance
| IRD | Status | Notes |
|-----|--------|-------|
| IRD-00N | ✅ Followed | — |
| IRD-00N | ⚠️ Diverged | [what changed and why] |

### Decisions Made During Implementation
[Decisions that go BEYOND what the IRD specified. If you followed the IRD exactly, write "None — IRD fully covered all decisions."]
- Decision: [what was decided]
  Reason: [why]
  IRD impact: [does this need an IRD update?]

### Artifacts Created / Modified
| File / Resource | Type | Location |
|----------------|------|----------|
| [name] | [Dockerfile / Terraform / K8s manifest / pipeline / script] | [path] |

### What the Next Session Needs to Know
[Anything about state, partially done work, known issues, or context that will matter next time]

### Follow-Up Issues Created
| Issue | Title | Why |
|-------|-------|-----|
| [ISSUE-NNN] | [title] | [IRD update / follow-up work / bug found] |
```

## Notes Quality Rules

1. **Concrete, not vague.** "Image size reduced from 1.2GB to 185MB" not "optimized the Docker image."
2. **IRD compliance is mandatory.** Every implementation note must have the compliance table.
3. **Divergences are not failures** — they are data. Document them so the IRD can be updated.
4. **Artifacts table is complete** — every file created or modified is listed.
5. **50–150 lines max** — if longer, the issue was too large and should have been decomposed.
