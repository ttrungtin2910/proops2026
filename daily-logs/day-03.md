# Daily Log — Tin (Trần Trung Tín) — Day 3 — 2026-04-06

## Today's Assignment
- [x] Q1 — Diagnose "pipeline didn't trigger": git status, log, remote
- [x] Q2 — Branches under the hood: merge vs rebase, exact commands
- [x] Q3 — Revert vs reset: rollback strategies, shared branch safety rule
- [x] Q4 — Find the breaking commit: git log flags, git diff, git bisect
- [x] Q5 — Full network chain: DNS → TCP → TLS → HTTP, failure modes per layer
- [x] Q6 — Ping works, curl hangs: dig, nc, traceroute — layer-by-layer diagnosis
- [x] Q7 — TLS cert errors: what certs are, 3 errors, openssl s_client, stateful firewalls
- [x] Q8 — Write memory/git.md and memory/networking-basics.md
- [ ] Publish IRD-001 to Notion via /write-ird
- [ ] Create first real Linear training issue via /create-linear-issue
- [ ] Open feat/w1-* branch following IRD-001 commit standards

## Completed
- [x] Q1: Diagnosed "pipeline didn't trigger" — git branch -avv, git log --oneline -5, git log origin/branch..HEAD, git status. Understood that "ahead N" = commits exist locally but not on remote.
- [x] Q2: Git branches explained as text files containing one commit hash (pointer, not copy). Merge vs rebase — both approaches with exact commands, when-to-use decision table, interactive rebase for squashing WIP commits.
- [x] Q3: Revert vs reset with ASCII history diagrams. Core rule: shared branch → always revert. Revert adds a new commit (safe, normal push). Reset rewrites history (dangerous, requires force push, can undo your rollback if others already pulled).
- [x] Q4: git log with flags (-S, --author, --after, --stat, -p), git diff between commits, git show, git bisect manual and automated (exit 0/1 script). When bisect is worth it vs manual reading.
- [x] Q5: Full DNS → TCP → TLS → HTTP trace. DNS resolution chain (browser cache → OS → recursive → root → TLD → authoritative). TCP 3-way handshake. TLS 1.3 handshake — key exchange, cert trust chain, cipher negotiation. HTTP request/response headers. Most common failure mode at each layer.
- [x] Q6: "Ping works = Layer 3 confirmed. Curl hangs = Layer 4 (TCP port) blocked." dig (DNS check), nc -zv -w 5 (port connectivity), traceroute -T -p 443 (path trace). Full port table: 10 essential ports with security rules. DROP vs REJECT behavior.
- [x] Q7: TLS certificate anatomy — what it is, trust chain (root CA → intermediate → end-entity). Three cert errors: expired (ERR_CERT_DATE_INVALID), hostname mismatch (ERR_CERT_COMMON_NAME_INVALID), self-signed (ERR_CERT_AUTHORITY_INVALID). openssl s_client commands. Stateful firewall — inbound vs outbound rules, connection state table, idle timeout.
- [x] Q8: memory/git.md expanded with 6 core commands, branch operations, conflict resolution, revert/reset, DevOps-specific git workflow (Dockerfile, Terraform, K8s, CI/CD). memory/networking-basics.md created with DNS chain, port table, firewall rules, TLS handshake, 4-command connectivity debug checklist.

## Not Completed
| Item | Reason | Time Spent |
|---|---|---|
| Publish IRD-001 to Notion | Discovery chain took full session | 0hr |
| Create first real Linear issue | Carried over again | 0hr |
| Open feat/w1-* branch | Carried over | 0hr |

## Extra Things Explored
- Traced a complete "add to cart" request from browser → DNS → TCP → TLS → Node.js → PostgreSQL with failure modes at each hop
- Explored what a cert's SAN field is and why CN is ignored by modern browsers
- Understood that `* * *` in traceroute does not always mean routing failure — routers may block ICMP but forward TCP

## Artifacts Built Today
- [x] `memory/git.md` — expanded: 6 core commands, branch ops, conflict resolution, revert/reset, DevOps workflow sections
- [x] `memory/networking-basics.md` — new file: DNS chain, 10-port table, stateful firewalls, TLS handshake, connectivity debug checklist

## How I Used Claude Code Today
Worked through the full Day 3 discovery chain using Claude as a Senior DevOps Engineer. Every question was answered with real commands and example outputs rather than theory. Key pattern: Claude framed each topic inside an incident scenario (pipeline broken → code broken → network broken), which made the concepts stick because they were attached to a real diagnosis workflow. The two memory files produced from Q8 are directly usable as agent context in future sessions.

## Blockers / Questions for Mentor
- IRD-001 is now 3 days overdue for publishing — should I publish it as-is or review the content first?
- The discovery chain fills the entire session, leaving no time for the carry-over tasks (IRD-001, Linear issue, feat branch). Should Day 4 prioritize those before starting new content?

## Self Score
- Completion: 7/10 (all 8 Qs done, carry-over tasks still pending)
- Understanding: 9/10
- Energy: 8/10

## One Thing I Learned Today That Surprised Me

A TLS certificate is not primarily about encryption — it is about authentication. The encryption key exchange (Diffie-Hellman) happens independently and does not require a certificate. The certificate's only job is to prove that the server you're talking to actually owns the hostname you requested. Without it, you could encrypt perfectly and still be sending your password to an attacker. This reframing made TLS errors make intuitive sense: expired cert = CA stopped vouching for this binding. Wrong hostname = cert vouches for the wrong identity. Self-signed = no third party is vouching at all.

---

## Tomorrow's Context Block

**Where I am:** End of Day 3, Week 1 — all 8 discovery chain questions completed: git state reading, branching/merge/rebase, revert/reset, git as debugging tool, DNS→TCP→TLS→HTTP chain, connectivity diagnosis (dig/nc/traceroute), TLS certs and openssl. Both memory files written: memory/git.md and memory/networking-basics.md.

**What to do tomorrow (Day 4):** Clear carry-over before new content — publish IRD-001 to Notion via /write-ird, create first real Linear training issue via /create-linear-issue, and open a feat/w1-* branch. Then start Day 4 topic.

**Open question:** IRD-001 is 3 days overdue — should I publish as-is or review the draft content first before running /write-ird?
