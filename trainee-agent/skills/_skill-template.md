<!--
WHAT SKILL FILES ARE:
Skill files are reusable Claude Code commands — pre-written prompts for tasks you do repeatedly.
Instead of writing the same prompt from scratch each time, you invoke a skill and Claude
executes it using the context you provide.

HOW TO INVOKE A SKILL IN CLAUDE CODE:
Option 1 — Slash command (if configured in your .claude/settings.json):
  /[skill-name]

Option 2 — Direct paste:
  Open the skill file, copy the contents of "The Prompt" section, paste into Claude Code,
  then add the specific inputs Claude needs.

Option 3 — Reference by file:
  Tell Claude Code: "Run the skill in skills/[name].md using these inputs: [your inputs]"

HOW TO BUILD A SKILL:
- Copy this template and rename it (e.g., skills/generate-dockerfile.md)
- Fill in every section — the most important part is "The Prompt"
- Test it, refine the prompt until the output is consistently good
- Document what inputs Claude needs before the skill runs reliably
-->

---

# Skill Name: [Name of the Skill]

**What It Does:** [One-line description — what does running this skill produce?]

---

## When To Use

(List the specific scenarios where you'd reach for this skill.)

-
-
-

---

## Input Required

(What information must you provide to Claude before running this skill? Be specific — the skill only works well if Claude has the right context.)

- [ ] [Input 1 — e.g., "The application language and framework"]
- [ ] [Input 2 — e.g., "The port the app runs on"]
- [ ] [Input 3 — e.g., "Any environment variables the app needs"]

---

## The Prompt

(This is the core of the skill — the exact prompt to use. Write it so it works as a standalone instruction to Claude Code.)

```
[Paste or write the full prompt here.

Write it as if you're giving Claude a complete, self-contained instruction.
Include placeholders in [BRACKETS] for the parts the user will fill in each time.

Example structure:
"You are acting as a DevOps engineer. I need you to [main task].

Context:
- Application: [APP_NAME]
- Language/Framework: [LANGUAGE]
- Environment: [ENV]

Requirements:
1. [Requirement 1]
2. [Requirement 2]

Output: [What exactly Claude should produce — a file, a command, a config, etc.]"
]
```

---

## Example Usage

(A fully filled-in example showing exactly how you'd use this skill in a real scenario.)

**Inputs provided:**
- [Input 1]: [example value]
- [Input 2]: [example value]
- [Input 3]: [example value]

**What you'd say to Claude Code:**
```
[Paste a complete, filled-in version of the prompt above using the example values]
```

---

## Expected Output

(What should Claude produce when this skill runs correctly? Describe the format, length, and content.)

-
-
-

---

## Notes / Variations

(Edge cases, common variations, things to watch out for, or ways to adapt this skill for different situations.)

- Variation: [description] — change [this part] of the prompt to [this]
- Edge case: [situation] — add [this context] before running
- Note: [anything important about output quality or reliability]
