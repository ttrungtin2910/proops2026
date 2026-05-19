# Daily Log — Tin (Trần Trung Tín) — Day 20 — 20 May 2026

## Today's Assignment (Day 20 — Review + Retention: Memory Audit + Quiz Debrief)
- [x] Q1 — Self-audit: score all 16 memory files against rubric (2/2 PASS, 1/2 NEEDS WORK, 0/2 GAP)
- [x] Q2 — Weakest-3 remediation plan: document what's missing, what must be added, fix timeline
- [x] Q3 — Self-quiz: score memory/day-20-quiz.md (+1 correct, +1 honest GAP, -1 wrong-but-confident)
- [x] Q4 — Quiz debrief: root-cause analysis of every wrong answer and every partial
- [x] Q5 — memory/INDEX.md: create agent-first index — one row per file, score, status, load guide
- [x] Q6 — gap-analysis.md: expand to 3-phase coverage (audit + quiz -1 + quiz partials), why/fix/target columns
- [x] Q7 — Rewrite weakest 3 memory file sections in own words with project-specific evidence
- [x] Q8 — Commit + push all Day 20 memory artifacts

## Environment
Windows 11 Pro, Claude Code CLI inside VSCode. No cloud resources used today — documentation and memory work only. All file edits done in `d:\14-AIOps_TinTT33\proops2026\memory\`. Committed as commit `6b5fce2`.

---

## Completed

- [x] **Q1 — Self-audit: 16 memory files, 22/32**

  Scored each file against a mentor-provided rubric. Scoring key:
  - **2/2 PASS** = file present AND contains project-specific evidence (real IDs, real error messages, real service names)
  - **1/2 NEEDS WORK** = file present and well-written, but content is generic
  - **0/2 GAP** = file fails the rubric's core requirement entirely

  Full results:

  | File | Score | Key finding |
  |---|---|---|
  | software-architecture.md | 1/2 | Generic patterns only — hook-gateway/qna-agent never mentioned |
  | git.md | 2/2 | Branch strategy + real commits present |
  | networking-basics.md | 0/2 | L3–L4 only — no Docker bridge, no K8s CoreDNS, kafka:9092 never appears |
  | linux-basics.md | 1/2 | All 5 sections present but generic reference material |
  | cloud-concepts.md | 1/2 | All examples use us-east-1, ap-northeast-2 never documented |
  | aws.md | 0/2 | Every ID is a placeholder (vpc-0abc123, sg-0abc123) |
  | docker.md | 2/2 | Real container names, 3 real Compose mistakes |
  | orchestration.md | 2/2 | Real Swarm recovery time observed (1–2s) |
  | kubernetes-core.md | 1/2 | CrashLoopBackOff row generic, not linked to real kafka/qna-agent failures |
  | kubernetes-advanced.md | 1/2 | HPA mechanics correct, no real scale event recorded |
  | kubernetes-project.md | 2/2 | 11 real services, 11 real failures with root cause + fix |
  | helm-basics.md | 2/2 | Non-circular definitions, real project chart table |
  | eks-practice.md | 2/2 | Real account 905418181527, real cost stack, 5 real errors |
  | bash-scripting.md | 2/2 | All 6 patterns, working healthcheck.sh |
  | deploy.sh + monitor-logs.sh | 2/2 | run() dry-run wrapper, .last-deploy idempotency, tail -F |
  | iac-basics.md | 1/2 | Commands present, real terraform plan/apply output not preserved |

  **Total: 22/32 (69%)**. Two files at 0/2 were the priority fixes.

- [x] **Q2 — Weakest-3 remediation plan → memory/day-20-audit.md**

  Three files at the bottom:

  1. **networking-basics.md (0/2):** Layer 5+ container networking section entirely absent. Docker bridge DNS, K8s CoreDNS, `kafka:9092` — none of it appears. Day 09 mistake of `localhost:9092` vs `kafka:9092` never documented.

  2. **aws.md (0/2):** Every resource ID is a placeholder. Real VPC ID `vpc-09c073830f75e7a64`, real S3 buckets `tin-tt-public-assets`/`tin-tt-private-assets`, real NAT GW `nat-046fd70f043e6e452` — all only in `aws-lab-day06.md`, not cross-referenced.

  3. **software-architecture.md (1/2):** Five generic patterns documented, but the actual RAG chatbot architecture (hook-gateway → Kafka → qna-agent → Milvus/OpenAI → websocket-responder) never appears. No Kafka topic names, no data model.

  Remediation timeline set in `memory/day-20-audit.md` → carried into `memory/gap-analysis.md`.

- [x] **Q3 — Self-quiz: 19/30**

  Scored `memory/day-20-quiz.md` (30 questions from Day 1–19 topics). Scoring: +1 correct, +1 honest GAP, -1 wrong-but-confident, no negative floor.

  ```
  +1 × 19 questions correct   = +19
   0 ×  6 questions partial   =   0
  -1 ×  3 wrong-but-confident =  -3
  ─────────────────────────────────
  Total                       =  19 / 30
  ```

- [x] **Q4 — Quiz debrief: 3 confident-wrongs + 6 partials → memory/day-20-quiz-score.md**

  **Three -1 penalties (wrong-but-confident):**

  | Q | My answer | Correct answer |
  |---|---|---|
  | Q3 | `docker compose down` removes named volumes | `down` keeps volumes; only `down -v` deletes them |
  | Q14 | Answered about CPU resource requests (wrong question) | Q asked to confirm base64 ≠ encryption in Secrets |
  | Q15 | `kubectl get deployment -o yaml` for HPA unknown targets | `kubectl top pods` — checks if metrics-server is running |

  **Root cause per miss:**
  - Q3: knew the rule but reversed it under pressure. `down -v` is the one that deletes.
  - Q14: read too fast, answered Q about CPU requests while Q14 was about Secrets encoding. Complete topic confusion.
  - Q15: guessed a plausible-sounding command instead of recalling the diagnostic table.

  **Six 0-score partials:** Q1 (exit code 138 vs 137), Q12 (apply vs create — missed "when it matters"), Q24 (Security Groups vs VPC orphan), Q27 (--dry-run WHY only, missed HOW), Q30 (files listed, no WHY each).

- [x] **Q5 — memory/INDEX.md created**

  Agent-first index file. Structure:
  - Header: audit score 22/32, quiz score 19/30, last updated
  - Status key: ✅ PASS (2/2) · ⚠️ NEEDS WORK (1/2) · ❌ GAP (0/2)
  - Main knowledge files table (16 rows): one-sentence coverage + Day-20 score + status
  - Scripts table: deploy.sh + monitor-logs.sh (both PASS)
  - Meta files: gap-analysis, audit, quiz-score
  - Load guide: task type → which files to load

  Purpose: next agent reads INDEX.md first to know which file is authoritative for any topic.

- [x] **Q6 — gap-analysis.md expanded: 9 rows → 17 rows (3 phases)**

  Previous format: just file + what's weak + plan + date.

  New format: file/concept → why weak (specific) → specific fix (exact content to add) → target date (Week 5–6).

  Three phases:
  - **Phase 1 (10 rows):** Every audit file scored 0/2 or 1/2
  - **Phase 2 (3 rows):** Every quiz -1 wrong-but-confident answer
  - **Phase 3 (4 rows):** Every quiz 0-score partial

  This means every known gap is now tracked. Nothing falls through.

- [x] **Q7 — Three memory file sections rewritten with project-specific evidence**

  **networking-basics.md §6 — Container Networking (132 lines added):**
  - Docker bridge model: each container's own `localhost` explained with diagram
  - The Day 09 mistake: `localhost:9092` → `kafka:9092` documented as the real error
  - Full hostname table for RAG stack (kafka/milvus/redis/mongodb/hook-gateway)
  - K8s CoreDNS pattern with real FQDN examples from `project-tin-lab` cluster
  - DNS comparison table: Compose vs K8s same-ns vs K8s cross-ns vs EC2
  - Debug commands: `docker exec` + `kubectl exec` connectivity tests

  **aws.md §6 — Day 06 Lab Overlay (80 lines added):**
  - VPC architecture diagram with real IDs: `vpc-09c073830f75e7a64`, all 3 subnet IDs, both RTBs
  - EC2 table: all 4 instances with real IDs, IPs, key pair names
  - Networking: NAT GW `nat-046fd70f043e6e452`, EIP alloc IDs, SG `sg-07b030604bb741cf4`, VPC endpoint
  - S3: `tin-tt-public-assets` + `tin-tt-private-assets` with status
  - Tag policy: required `Owner=tin_tt` + `Email=ttrungtin.work@gmail.com` on every resource
  - IAM error: `ec2:CreateKeyPair` denied by `trainee-tag-enforcement` + exact fix
  - S3 self-lockout gotcha: what caused it, why Explicit Deny beats AdministratorAccess, recovery via EC2 → VPC endpoint

  **kubernetes-advanced.md — Two targeted fixes:**
  - Secret section: added exact decode command + Q14 miss annotation (`echo "..." | base64 -d` = plain text, no key)
  - HPA section: added numbered diagnostic sequence explicitly noting `kubectl top pods` as step 1 and why `kubectl get deployment -o yaml` is wrong for this problem (Q15 miss annotation)

- [x] **Q8 — Commit + push**

  ```
  git add memory/aws.md memory/gap-analysis.md memory/kubernetes-advanced.md \
          memory/networking-basics.md memory/INDEX.md \
          memory/day-20-audit.md memory/day-20-quiz-score.md
  git commit -m "Day 20 — memory audit + quiz debrief + weakest-3 rewrites"
  git push
  # → 6b5fce2, pushed to main
  ```

  7 files changed, 532 insertions, 9 deletions.

---

## Not Completed

| Item | Reason | Deferred to |
|---|---|---|
| `docker.md` §19 env var table (hook-gateway/qna-agent) | Low time after core deliverables done | Day 21 |
| `docker.md` §10 Observability RAM baselines | Same | Day 22 |
| `software-architecture.md` §6 Mock Project Architecture | RAG chatbot service map needs careful reconstruction | Day 22 |
| `iac-basics.md` real terraform plan/apply output | Need to extract from day-19 log first | Day 21 |
| `kubernetes-advanced.md` real HPA scale event | Requires running live HPA lab, not documentation work | Day 28 |

---

## Extra Things Explored

- **Audit scoring methodology:** The difference between "file exists and is detailed" vs "file contains evidence I was actually there" is larger than expected. aws.md had 833 lines of well-written content but scored 0/2 because every ID was placeholder. Quality of content ≠ audit score — specificity is the only metric.

- **Quiz -1 mechanics:** The -1 penalty for wrong-but-confident is more punishing than a simple 0. Q14 answered a completely different question with confidence — if honest GAP ("I don't know") was given instead, score would have been 0 not -1. The lesson: when memory of a question feels fuzzy, hedge explicitly.

- **Phase 3 partial analysis:** Six answers got 0 because they were correct on mechanics but missed the applied consequence ("when does it matter", "why each one"). This pattern — knowing HOW but not WHY — is a consistent gap across docker.md, kubernetes-core.md, iac-basics.md, and bash-scripting.md.

- **networking-basics.md §6 length:** The container networking section ended up 132 lines — longer than any other single section in the file. This reflects how much was genuinely missing: Docker bridge model, Compose DNS rule, full hostname table, K8s CoreDNS, comparison table, debug commands — all were absent before today.

---

## Artifacts Built Today

- [x] `memory/INDEX.md` — agent-first index, 16-file knowledge table, load guide
- [x] `memory/day-20-audit.md` — 16-file audit table, scores 22/32, weakest-3 remediation plan
- [x] `memory/day-20-quiz-score.md` — 30-question debrief, 19/30, 3 confident-wrong root-cause analysis
- [x] `memory/gap-analysis.md` — expanded to 17 rows, 3-phase coverage, why/fix/target columns
- [x] `memory/networking-basics.md` — §6 Container Networking added (132 lines)
- [x] `memory/aws.md` — §6 Day 06 Lab Overlay added (80 lines, real IDs)
- [x] `memory/kubernetes-advanced.md` — Secret decode example + HPA Q15 diagnostic fix

---

## How I Used Claude Code Today

Day 20 was a meta-day: the work was on the knowledge system itself, not on infrastructure. The most valuable part was the structured audit — going file by file with a fixed rubric forced honest scoring rather than optimistic self-assessment. "Does this file contain specific, project-verifiable evidence?" is a different bar than "Is this file well-written?"

The quiz debrief revealed a pattern: the -1 wrong-but-confident answers all came from confidently producing a plausible-but-wrong answer rather than acknowledging uncertainty. The fix is not to learn more facts but to develop the habit of hedging when memory is not crisp. "I think it's X, but I'm not certain" is worth +0 under this scoring system vs -1 for stating X confidently wrong.

The gap-analysis expansion to 3 phases is the most durable artifact — it converts every known failure mode into a specific, actionable remediation item. Future sessions can pick from this list rather than discovering gaps by failure.

---

## Blockers / Questions for Mentor

- **Gap remediation timing:** I have 4 deferred items from audit + 8 more from quiz partials (Days 21–22). Should these be completed as the first task of each day before the new assignment, or treated as a separate parallel track? Currently they block some 1/2 → 2/2 upgrades in the audit score.

- **Real HPA scale event (Day 28):** This requires actually running a load generator against a live deployment. Should this be part of a specific future assignment, or should I spin up minikube and run it as a standalone lab during Week 5?

---

## Self Score
- Completion: 9/10 — All primary deliverables done; 5 remediation items deferred by design (require future sessions)
- Understanding: 9/10 — Audit revealed exactly where knowledge is shallow vs deep; quiz debrief identified 3 specific confident-wrong patterns
- Energy: 8/10 — Documentation + honest self-assessment day; high concentration required to score honestly rather than generously

---

## One Thing I Learned Today That Surprised Me

The S3 self-lockout gotcha from Day 06 is a perfect example of why `Explicit Deny s3:*` is catastrophically broad. An explicit Deny in a resource-based policy overrides **every** identity-based Allow — including `AdministratorAccess`. The only way to recover was from inside the VPC (via EC2 → VPC Gateway Endpoint) where the `aws:SourceVpc` condition evaluated as the allowed VPC, bypassing the Deny. If there was no EC2 running in the VPC at that moment, recovery would have required opening an AWS Support ticket. The lesson is: never write `Deny s3:*` — always scope Deny to read-only actions only and leave management operations (`PutBucketPolicy`, `DeleteBucketPolicy`) unrestricted.

---

## Tomorrow's Context Block

Day 20 complete — memory audit (22/32), quiz debrief (19/30), gap-analysis expanded to 17 rows across 3 phases, networking-basics §6 Container Networking + aws.md §6 Day 06 Lab Overlay + kubernetes-advanced.md Secret/HPA fixes committed and pushed (commit 6b5fce2).
Tomorrow (Day 21): execute top-priority gap-analysis items — docker.md (compose down -v callout, exit code 137 correction, §19 env var table for hook-gateway/qna-agent), iac-basics.md (.gitignore why column, paste real terraform plan output from day-19 log), kubernetes-core.md (apply-vs-create CI/CD note, CrashLoopBackOff cross-reference). Then start Week 5 assignment (CI/CD).
Open question: should gap remediation run before or in parallel with new assignments? Currently 5 items deferred to Day 21–22 with risk of accumulating if each day adds new gaps.
