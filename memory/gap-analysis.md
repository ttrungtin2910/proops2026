# Memory Gap Analysis

| File | What is weak | Gap type | Plan to fix | Fix by |
|------|-------------|----------|-------------|--------|
| memory/docker.md | Section 19 Secrets: lists `cp` commands only — no per-service env var table, no "forgot .env.example" lesson entry | specificity | Add env var table for hook-gateway/qna-agent + lesson learned entry to Section 19 | Day 20 |
| memory/docker.md | Section 10 Observability: placeholder labels and fake log group path, no RAM baselines for real services | specificity | Replace with `docker stats` baselines per service + Milvus OOM lesson (replacement written, not yet pasted) | Day 20 |
| memory/aws.md | Day 06 lab resources (VPC, SG, S3 bucket) live in a separate project file — aws.md has no project overlay, no real IDs, no recorded mistakes | missing entirely | Add Day 06 overlay section: actual VPC ID, SG IDs, bucket name, region, and the 2 carry-over fixes from the lab | Day 20 |
