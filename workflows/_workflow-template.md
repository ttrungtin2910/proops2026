<!--
WHAT WORKFLOW FILES ARE:
Workflow files describe multi-step agentic processes — sequences of actions where Claude Code
acts as your pair, guiding you through each step or executing steps on your behalf.

Unlike skill files (which are single prompts for single tasks), workflow files capture
an end-to-end process: from preconditions through execution through verification.

They are the highest-level artifact in your agent — they tie together memory files
(what you know) and skill files (what you can do) into a complete repeatable procedure.

WHEN TO CREATE A WORKFLOW FILE:
- When a task takes multiple steps that must happen in order
- When a task involves multiple tools, systems, or environments
- When you've done something once, figured out the right sequence, and want to make it repeatable
- Whenever a day's assignment asks for one

HOW TO USE A WORKFLOW FILE:
Tell Claude Code: "Follow the workflow in workflows/[name].md"
Then provide the inputs/context it needs at the start.
Claude will walk through each step, using the specified skills and prompts.
-->

---

# Workflow Name: [Name of the Workflow]

**Goal:** [What end state does this workflow achieve? One sentence — e.g., "A containerized application is running in a Kubernetes cluster with health checks passing."]

---

## Trigger

(When do you use this workflow? What situation or task kicks it off?)

-

---

## Prerequisites

(What must be true before you start? List tools, access, configs, and knowledge required.)

- [ ] [Prerequisite 1 — e.g., "Docker is installed and running"]
- [ ] [Prerequisite 2 — e.g., "You have a working Dockerfile for the application"]
- [ ] [Prerequisite 3 — e.g., "kubectl is configured to point to the target cluster"]
- [ ] [Prerequisite 4 — e.g., "You have read memory/kubernetes-core.md"]

---

## Steps

(Each step has three parts: the Action you take, the Claude Prompt to use, and the Expected Result.)

---

### Step 1: [Step Name]

**Action:** [What you or Claude does in this step]

**Claude Prompt:**
```
[The exact prompt to give Claude Code for this step.
Include placeholders in [BRACKETS] for variable inputs.]
```

**Expected Result:** [What should be true after this step completes successfully]

---

### Step 2: [Step Name]

**Action:** [What you or Claude does in this step]

**Claude Prompt:**
```
[The exact prompt to give Claude Code for this step.]
```

**Expected Result:** [What should be true after this step completes successfully]

---

### Step 3: [Step Name]

**Action:** [What you or Claude does in this step]

**Claude Prompt:**
```
[The exact prompt to give Claude Code for this step.]
```

**Expected Result:** [What should be true after this step completes successfully]

---

### Step 4: [Step Name]

**Action:** [What you or Claude does in this step]

**Claude Prompt:**
```
[The exact prompt to give Claude Code for this step.]
```

**Expected Result:** [What should be true after this step completes successfully]

---

(Add more steps as needed. Most workflows have between 4 and 8 steps.)

---

## Verification

(How do you confirm the workflow succeeded end-to-end? List specific commands to run or outputs to check.)

```bash
# [What this check confirms]
[verification command]
```

- Expected output: [what a successful result looks like]

---

## Rollback

(How do you undo or recover if something goes wrong? List specific steps to reverse the workflow.)

1. [Rollback step 1]
2. [Rollback step 2]
3. [Rollback step 3]

```bash
# [Rollback command if applicable]
[command]
```

---

## Related Skills

(Which skill files does this workflow use? List them so you know what to build first.)

- `skills/[skill-name].md` — used in Step [N]
- `skills/[skill-name].md` — used in Step [N]

---

## Time Estimate

- First time running: [X] hours
- Subsequent runs (familiar): [X] minutes
- Notes: [anything that affects timing — e.g., "cluster spin-up adds 10 min on AWS"]
