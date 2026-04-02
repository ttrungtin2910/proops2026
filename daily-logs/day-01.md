# Daily Log — Tin (Trần Trung Tín) — Day 1 — 2026-04-02

## Today's Assignment
- [x] Set up ProOps2026 repo from template
- [x] Configure Claude Code (CLAUDE.md identity + persona)
- [x] Connect Notion MCP integration
- [x] Connect Linear MCP integration
- [x] Fill in Training Spec in Notion
- [x] Write IRD-001 (Git Standards)

## Completed
- [x] Git repo initialized (`proops2026`, branch: main) with Day 01 template commit
- [x] CLAUDE.md updated — identity filled in (Tin, AI Engineer → K8s Platform Engineer, Senior DevOps Engineer persona)
- [x] Notion workspace created: root page + Training Spec + DOPs tracker + IRDs tracker
- [x] Linear workspace confirmed: ProOps2026Claude team, user ttrungtin2910
- [x] Notion MCP and Linear MCP verified working
- [x] Training Spec fully filled — environment section completed (cloud: AWS + GCP, repo: github.com/ttrungtin2910/proops2026)
- [x] IRD-001 (Git Standards) drafted — branch naming, commit format, merge strategy, agent rules defined

## Not Completed
| Item | Reason | Time Spent |
|---|---|---|
| First real Linear training issue | Setup + carryover tasks took full Day 1–2 | 0hr |

## Extra Things Explored
- Explored Claude Code memory system — how session context is lost and how memory files survive across sessions
- Explored C.R.A.F.T. prompting framework — Training Spec is the standing Context block
- Reviewed all DOP/IRD due dates and mapped them to the 8-week calendar

## Artifacts Built Today
- [x] Memory file: `memory/user_profile.md` — Tin's background, ML→DevOps bridge, calibration notes
- [x] Memory file: `memory/project_status.md` — Program position, Day 1 completions, upcoming deadlines
- [x] Memory file: `memory/reference_workspaces.md` — Notion, Linear, and Git workspace URLs and IDs
- [x] Notion page: `ProOps2026 — Trung Tín Trần` — root workspace with Training Spec, DOPs, IRDs sub-pages
- [x] Notion page: `📋 Training Spec` — fully filled (identity, stack, environment, cloud: AWS+GCP, repo URL)
- [x] IRD-001 draft — Git Standards: branch naming, commit convention, merge strategy, agent rules (7 decisions)

## How I Used Claude Code Today
Used Claude Code to set up the full Day 1 workspace: read program state from Notion and Linear, ran `/setup-notion` to create the doc structure, filled in Training Spec with real content. Claude bridged my ML background to DevOps concepts which made the program structure click faster. The memory system needed to be set up manually — Claude doesn't persist context automatically between sessions.

## Blockers / Questions for Mentor
- ~~What cloud provider should I use for this program — AWS, GCP, or Azure?~~ **Resolved: AWS + GCP**
- Do I need a real domain name for K8s ingress exercises, or will local/minikube cover Week 3?
- ~~IRD-001 is due end of Day 3 — what level of detail is expected for Git Standards at this stage?~~ **Resolved: full standard with naming tables + agent rules**

## Self Score
- Completion: 9/10
- Understanding: 8/10
- Energy: 8/10

## One Thing I Learned Today That Surprised Me

Claude Code loses all session context when the session closes — it's essentially stateless. The memory file system (`memory/`) is the only bridge between sessions. Without it, every new session starts completely cold even if the codebase is right there. This is a bigger operational concern than I expected — keeping memory files updated is as important as keeping code committed.

---

## Tomorrow's Context Block
*(Write 3 sentences. This is the first thing Claude reads in your next session.
Be specific — not "I learned Docker today" but "I have a working Dockerfile for
the Node app at ~/projects/taskflow, it builds but the container exits immediately
because the start command is wrong, tomorrow I'm debugging that.")*

**Where I am:** End of Day 2, ProOps2026 Week 1 — all Day 1 assignments complete: repo initialized, CLAUDE.md set, Notion workspace live, Training Spec fully filled (AWS+GCP, GitHub repo confirmed), IRD-001 (Git Standards) drafted with branch naming, commit convention, squash merge strategy, and agent rules.

**What to do tomorrow (Day 3):** Approve and publish IRD-001 to Notion under the IRDs section, create the first real Linear training issue, and start Day 3 topic work — first commit on a `feat/w1-*` branch following IRD-001 standards.

**Open question:** Do I need a real domain name for K8s ingress exercises in Week 3, or will minikube + local DNS cover it?
