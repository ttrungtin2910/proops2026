=== Day 06 Extended | Trần Trung Tín | 13 Apr 2026 ===

GitHub : https://github.com/ttrungtin2910/proops2026
Notion : https://www.notion.so/33664e2cb7a881388ae8c0c8fb451fa9
Commit : NOT pushed

ARTIFACTS
memory/aws.md                DONE      proops2026/memory/aws.md
Daily Log day-06             DONE      proops2026/daily-logs/day-06.md
IRD-001 (Notion)             MISSING   carry-over Day 3 — 10 days overdue, not yet published
Linear training issue        MISSING   carry-over Day 3 — blocked on IRD-001
feat/w1-* branch             MISSING   carry-over Day 3 — blocked on Linear issue

BLOCKED
IRD-001 publication — 10 days overdue. All 5 lab steps completed but carry-over tasks pushed out again by lab session duration. Must be cleared Day 7 before any new content.

TOMORROW
Where I am: End of Day 6 Extended, Week 2 — AWS Architecture Practice Lab complete. Full extended architecture built: Elastic IP on EC2 Public (static IP), NAT Gateway (private subnets have outbound internet), OpenVPN EC2 with EIP (direct SSH into private subnet without bastion), S3 public bucket (anonymous read via bucket policy), S3 private bucket (VPC-CIDR-only via Deny + NotIpAddress). memory/aws.md written and committed.
What to do tomorrow (Day 7): Check Day 7 training brief for next topic. Clear carry-over first if Day 7 has a light discovery chain: publish IRD-001 via /write-ird, create Linear training issue via /create-linear-issue, open feat/w1-* branch. Cost hygiene before starting: verify NAT Gateway + OpenVPN EC2 billing status.
Open question: IRD-001 is 10 days overdue — does it need to be cleared before Day 7 content, or is parallel-track publication acceptable?

QUESTION
NAT Gateway is running at $0.045/hr (~$1.08/day). Should I delete it at end of each lab day and recreate it, or leave it running for Week 2 continuity?
