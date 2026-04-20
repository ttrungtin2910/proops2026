# Daily Log — Tin (Trần Trung Tín) — Day 10 — 2026-04-20

## Today's Assignment (Day 10 — Agent Checkpoint: Memory Review)
- [x] Q1 — Ask Claude what makes a memory file actually useful from its perspective
- [x] Q2 — Read docker.md fully and identify the weakest section before testing
- [x] Q3 — Test docker.md with a real question: "container crashes after docker compose up — debug it"
- [x] Q4 — Rewrite the weakest section based on the diagnosis
- [x] Q5 — Paste improved section back, re-run the same test, compare answers
- [x] Q6 — Pick a second memory file and run the full audit method on it
- [x] Q7 — Write `memory/gap-analysis.md`

## Environment
Windows 11 Pro, Claude Code CLI inside VSCode. All work done via conversation — no terminal commands today. Memory files in `memory/`, daily brief at `daily-briefs/day-10.html`.

## Completed

- [x] **Q1 — What makes a memory file useful:**
  Got a clear rubric from Claude. Three types that help: (1) decisions with their reasons — the "why" behind a choice that can't be derived from code, (2) specific environment facts — account IDs, cluster names, naming conventions, things that prevent placeholder output, (3) rejected approaches and why they failed — stops Claude from re-suggesting what was already discarded. Three things that look useful but aren't: (1) best-practice restatements ("always use resource limits") — Claude already knows these, (2) progress logs ("Day 3 complete") — tells what was done, not what Claude needs to know, (3) conceptual overviews of standard topics — Docker uses namespaces, etc. If a sentence would appear unchanged in a blog post, it doesn't belong in a memory file.

- [x] **Q2 — Diagnosed weakest section of original docker.md:**
  The original docker.md (before today) was a comprehensive Docker reference — essentially a textbook. Applied the rubric: almost no section contained a decision with a reason, a specific environment fact, or a rejected approach. The single weakest section was **Secrets and Configuration** — it listed three injection approaches (env-file, mounted files, AWS/GCP/Vault Secrets Manager) without recording which approach was actually chosen, and its "Never" bullets were pure best-practice restatements that change nothing about Claude's output. Diagnosis: **(b) specificity**.

- [x] **Q3 — Test on original docker.md — FAILED:**
  Ran the test: "container crashes after docker compose up — debug it." Result: Claude had to immediately flag that the file contained zero Docker Compose content — no `docker compose` commands, no `docker compose logs`, no compose-specific service names. The file had sections on `docker run`, `docker exec`, `docker ps` — all raw Docker commands — but the actual workflow for Compose-based debugging was completely absent. This was a **(c) coverage** gap, not just specificity.

- [x] **Q4 — Rewrote docker.md (new version with Compose + Project Overlay):**
  The new docker.md is structurally different: 21 sections organized as Portable Core + Project Overlay. Added: Section 12 (Compose file structure), Section 13 (Compose networking + DNS service name rule), Section 16 (Standard Debug Decision Tree with `docker compose logs`), Section 17 (Common Failure Patterns table), Section 18 (Project Overlay Template), Section 19 (Day 09 Stack Overlay with real services: hook-gateway, qna-agent, websocket-responder, frontend + known crash patterns + mistakes already made). Also rewrote Secrets section inside Section 19 with `cp hook-gateway/.env.example hook-gateway/.env` as the actual setup command.

- [x] **Q5 — Re-test on new docker.md — PARTIAL PASS:**
  The same question now gets a completely different answer. Before: "I cannot answer — the file has no Docker Compose content." After: specific steps using `docker compose logs --tail 50 hook-gateway`, exit codes cross-referenced with Section 19 known crash patterns (qna-agent + Milvus, websocket-responder + Kafka), and real mistakes from the project (used localhost:9092, forgot `depends_on: condition: service_healthy`). Remaining gap identified: **Section 10 Observability** — has placeholder labels, fake log group paths, no RAM baselines for any real service.

- [x] **Q6 — Second audit on docker.md Section 10:**
  Ran the full 4-step method on Section 10. Test question: "qna-agent is using too much memory and getting killed. How do I check its current resource usage and what should I look for?" Result: PARTIAL FAIL. File gives the command (`docker stats qna-agent --no-stream`) and the exit code (137 = OOM). But no baseline — I can't tell if 700MB for qna-agent is normal or a problem because the file has no data on expected RAM ranges per service. Wrote replacement Section 10 with: real `docker stats` commands targeting real services, expected RAM table (milvus: 1–2GB, qna-agent: 300–600MB, hook-gateway: <200MB), OOM debug flow, lesson learned (Milvus crashed silently on first start — OOMKilled was true, spent 10 minutes checking dependencies before checking OOM flag).

- [x] **Q7 — Wrote memory/gap-analysis.md:**
  Three rows: docker.md Secrets (specificity — per-service env vars + lesson entry missing), docker.md Section 10 Observability (specificity — no RAM baselines, replacement written but not yet pasted), memory/aws.md (missing entirely — Day 06 lab resource IDs live in a separate project file, aws.md has no project overlay). All rows set Fix by: Day 20.

## Not Completed
| Item | Reason | Days Overdue |
|---|---|---|
| Linear training issue | Still carry-over | 14 days |
| feat/w1-* branch | Blocked on Linear issue | 14 days |
| Section 10 replacement pasted into docker.md | Written, not yet committed | — |

## Artifacts Built Today
- [x] `memory/docker.md` — structurally rebuilt (Portable Core + Project Overlay, Section 19 Day 09 Stack)
- [x] `memory/gap-analysis.md` — 3 rows, each with named gap type + specific fix plan + Day 20 deadline
- [x] `daily-logs/day-10.md` — this file

## How I Used Claude Code Today
Checkpoint day — the whole session was a methodical audit rather than new learning. Most valuable: testing before fixing. The original instinct was to look at the file and decide "the Secrets section looks weak" — but running the actual test question revealed a much larger gap (zero Compose coverage) that wouldn't have been found by reading alone. The test-diagnose-fix-retest loop is the actual deliverable from today, not just the improved file.

The second audit (Section 10 Observability) showed the same pattern: the section "looked fine" but failed a real operational question because it had no baselines. A command with no baseline is half a debugging tool — you can run `docker stats` but you can't interpret the output without knowing what normal looks like.

## Blockers / Questions for Mentor
- The docker.md Section 10 replacement was written in the session but not yet pasted into the actual file — should this be committed before Day 11, or can it wait until the Day 20 audit?
- memory/aws.md gap: the Day 06 resource IDs (VPC, SG, S3 bucket) are in a separate project memory file. Should I merge them into aws.md or keep them separate and just link? The gap-analysis.md flags this as "missing entirely" but there may be a reason the project overlay was kept separate.
- Linear carry-over at 14 days: at what point does this become a blocker for Week 3 work?

## Self Score
- Completion: 10/10 (all 7 questions done)
- Understanding: 9/10 (the test-diagnose-fix loop is now a concrete method, not an abstract idea)
- Energy: 8/10

## One Thing I Learned Today That Surprised Me

Running the test question on a file that I thought was decent revealed an entire missing topic — Docker Compose — that I hadn't noticed because I was reading the file as a human, not as an AI trying to answer a specific question. The difference: when I read the file, I fill in gaps from my own knowledge automatically. When Claude reads it, there are no gaps to fill — if the information isn't there, the answer fails. This means the only valid way to audit a memory file is to actually test it with a real question and evaluate the answer, not to read it and decide it "looks complete." The quality of a memory file is only visible through its output.

---

## Tomorrow's Context Block

**Where I am:** End of Day 10, Week 2 — Memory audit checkpoint complete. All 7 discovery questions done. Artifacts: docker.md rebuilt (Portable Core + Day 09 Stack Overlay), gap-analysis.md created (3 rows, Fix by Day 20). Carry-over: Linear training issue and feat/w1-* branch still open (14 days). Section 10 Observability replacement written but not yet pasted into docker.md.

**What to do tomorrow (Day 11):** Orchestration week begins — Kubernetes core. Read Day 11 brief first. Before starting: paste Section 10 replacement into docker.md and commit the full Day 10 work. Start a new `memory/kubernetes-core.md` using the same 3-layer structure from docker.md (mental model + operational workflow + project overlay).

**Open question:** For gap-analysis.md aws.md row — should the Day 06 resource IDs be merged into aws.md, or kept in a separate project file and linked from aws.md?
