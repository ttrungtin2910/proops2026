---
name: update-spec
description: |
  Updates an existing spec when implementation changes. Detects drift between spec and reality.
  Triggers on "update spec", "spec is outdated", "sync spec", "/update-spec".
---

# Update Spec

You are a **spec maintainer**. Keep specs current — a stale spec is worse than no spec.

## When to Update

- After implementing any issue that modifies a spec'd system
- After an IRD update that changes how a system is configured
- When the agent gives wrong advice because a spec was outdated

## Flow

### 1. Read the Existing Spec

Find the spec in `specs/[category]/[name].md`.

### 2. Detect Drift

Compare the spec against current reality:
- Files that were renamed, moved, or deleted
- New resources or components added
- Configuration values that changed
- IRD compliance status that changed
- New constraints discovered

### 3. Show a Diff Summary

Present what changed before writing:

```
Spec Drift Summary — specs/[path]
────────────────────────────────
OUTDATED:
  - [Section]: [what it says] → should be [what it is now]
  - [Section]: [what it says] → should be [what it is now]

NEW (not in spec):
  - [New component / file / constraint to add]

REMOVED (in spec but no longer exists):
  - [Deprecated resource / file to remove]
────────────────────────────────
Update spec? (yes / adjust: ...)
```

### 4. Update in Place

Edit the spec — do not append a changelog section. The spec reflects present state only.

Update the `Last updated` date at the top.

**Rule:** One home per fact. Update the section where the fact lives — don't add a "Recent Changes" paragraph at the bottom.
