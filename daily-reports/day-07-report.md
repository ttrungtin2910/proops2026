=== Day 07 | Trần Trung Tín | 14 Apr 2026 ===

GitHub : https://github.com/ttrungtin2910/proops2026
Notion : https://www.notion.so/33664e2cb7a881388ae8c0c8fb451fa9
Commit : NOT pushed

ARTIFACTS
memory/docker.md             DONE      proops2026/memory/docker.md
Daily Log day-07             DONE      proops2026/daily-logs/day-07.md
Linear training issue        MISSING   carry-over — 11 days overdue
feat/w1-* branch             MISSING   carry-over — blocked on Linear issue

BLOCKED
Linear training issue — 11 days overdue. Docker hands-on day consumed full session again.

TOMORROW
Where I am: End of Day 7, Week 2 — Docker Core complete. All 8 discovery questions done plus Explore Further (multi-stage builds, exec-form PID 1 signal handling, non-root USER + --read-only security hardening). Artifact: memory/docker.md with 5 required sections + secrets config + debugging cheatsheet. Carry-over: Linear training issue and feat/w1-* branch still open (11 days overdue).
What to do tomorrow (Day 8): Design day — Define Mock Project (DOP + IRD + Architecture). Read Day 8 brief first. Before starting: check whether the Linear training issue carry-over should be cleared during this design session (the DOP and IRD for the mock project are exactly what a Linear issue would reference). Cost hygiene: NAT Gateway + OpenVPN EC2 still running.
Open question: For the USER instruction in a Dockerfile — is it redundant when Kubernetes enforces non-root via Pod securityContext, or should both always be set as defense-in-depth?

QUESTION
For non-root containers: is USER in the Dockerfile redundant when K8s enforces non-root via Pod securityContext — or should both always be set as defense-in-depth?
