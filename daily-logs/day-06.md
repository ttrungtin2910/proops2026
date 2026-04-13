# Daily Log — Tin (Trần Trung Tín) — Day 6 Extended — 2026-04-13

## Today's Assignment (Day 6 Extended — AWS Architecture Practice Lab)
- [x] Step 1 — Elastic IP: allocate and associate to EC2 Public
- [x] Step 2 — NAT Gateway: create in public subnet, update private + database route tables
- [x] Step 3 — OpenVPN EC2: launch from Marketplace AMI, assign EIP, configure SG, download .ovpn
- [x] Step 4 — S3 Public Bucket: create, disable block-public-access, attach GetObject:* policy, verify URL access
- [x] Step 5 — S3 Private Bucket: create, keep public access blocked, attach VPC-CIDR-only Deny policy, verify access from EC2 Private vs laptop
- [ ] Publish IRD-001 to Notion via /write-ird (carry-over, Day 3 → Day 6, 10 days overdue)
- [ ] Create first real Linear training issue via /create-linear-issue
- [ ] Open feat/w1-* branch following IRD-001 commit standards

## Environment
AWS Console + AWS CLI — ap-southeast-1. Day 6 base infrastructure already running:
VPC 10.11.0.0/16, public/private/database subnets, IGW, EC2 Public + EC2 Private + EC2 Database.

## Completed

- [x] **Step 1 — Elastic IP:** Allocated EIP from AWS pool (`aws ec2 allocate-address --domain vpc`), associated with EC2 Public instance. Verified by stopping and starting EC2 Public — public IP unchanged. Core concept: without EIP, EC2's public IP is re-assigned from AWS's pool on every start; any DNS record or client config pointing to the old IP breaks. EIP is the cheapest fix (~$0/hr when associated). Cost trap: unassociated EIP bills at $0.005/hr — release immediately if not in use.

- [x] **Step 2 — NAT Gateway:** Allocated a second EIP for the NAT Gateway itself. Created NAT Gateway in public subnet, waited ~60s for `available` state. Added `0.0.0.0/0 → nat-*` route to private route table and database route table. Verified from EC2 Private: `curl https://google.com` succeeds. Verified from EC2 Database: same result. Core concept: NAT Gateway allows private subnet instances to initiate outbound connections (OS patches, package downloads, API calls) while remaining completely unreachable from inbound internet. Traffic path: EC2 Private → NAT Gateway (public subnet) → IGW → internet. Return traffic reverses. Inbound: blocked because there is no public IP on EC2 Private, and the route table has no entry allowing inbound from IGW.

- [x] **Step 3 — OpenVPN EC2:** Found OpenVPN Access Server AMI via AWS Marketplace. Launched EC2 in public subnet with dedicated EIP (so .ovpn config remains valid after restarts). Configured security group: UDP 1194 (OpenVPN tunnel), TCP 943 (admin UI), TCP 443 (client download UI), TCP 22 (initial SSH setup only — restricted after). SSH'd as `openvpnas@<eip>`, ran setup wizard, set admin password via `sudo passwd openvpn`. Downloaded .ovpn config from client UI (`https://<eip>/`). Imported into OpenVPN client, connected. Verified: while connected to VPN, SSH'd directly into EC2 Private at `10.11.11.x` — no jump host, no bastion needed. Core concept: VPN tunnel places the client's traffic inside the VPC network. All private subnet IPs become reachable directly. This replaces the need for a bastion host for engineer access, while keeping SSH off all security group inbound rules.

- [x] **Step 4 — S3 Public Bucket (`proops2026-public-tin`):** Created bucket, disabled block-public-access, attached bucket policy with `Effect:Allow Principal:* Action:s3:GetObject`. Uploaded `test.txt`. Accessed `https://proops2026-public-tin.s3.ap-southeast-1.amazonaws.com/test.txt` in browser with no credentials — file loaded. Core concept: S3 bucket policy with `Principal:*` + `GetObject` = anonymous read. This is how static website assets, public CDN origins, and frontend build artifacts are served. Every other action (Put, Delete, List) remains private by default.

- [x] **Step 5 — S3 Private Bucket (`proops2026-private-tin`):** Created bucket, confirmed all block-public-access flags are true. Attached Deny policy using `NotIpAddress` condition on `aws:SourceIp` with VPC CIDR `10.11.0.0/16`. Uploaded `private.txt` from laptop (upload succeeds because laptop PUT is not covered by the Deny on reads). Verified from EC2 Private: `aws s3 ls s3://proops2026-private-tin` — success. Verified from laptop without VPN: `aws s3 ls s3://proops2026-private-tin` — Access Denied. Connected VPN, ran same command from laptop — success (traffic now originates from VPC CIDR). Core concept: `NotIpAddress` + `Deny` = block all requests NOT originating from the VPC. The Deny effect overrides any Allow in the policy. This pattern is used for application logs, backups, and internal data that should never be reachable from the internet.

- [x] **memory/aws.md written** — 5 sections: EC2 lifecycle (state machine, persist vs lose table, CLI patterns), S3 operations (bucket creation, policies, access patterns, CLI), VPC/SG/IGW/NAT (topology, subnet types, security group rules, connectivity matrix), IAM roles vs users (credential chain, instance profiles, policy types), 10 daily CLI commands.

## Not Completed
| Item | Reason | Days Overdue |
|---|---|---|
| Publish IRD-001 to Notion | Lab steps consumed full session | 10 days |
| Create Linear training issue | Blocked on IRD-001 | 10 days |
| Open feat/w1-* branch | Blocked on Linear issue | 10 days |

## Extra Things Explored (Explore Further)
- **CloudWatch alarm:** Created CPUUtilization alarm on EC2 Private (threshold 80%), SNS topic + email subscription. Triggered manually with `stress --cpu 2` — email notification received. This is the minimum viable monitoring for any production EC2 instance.
- **S3 bucket versioning:** Enabled on private bucket, uploaded same key twice with different content, confirmed two versions with `aws s3api list-object-versions`. Versioning protects against accidental overwrites and deletes but does NOT protect against: bucket deletion, regional outage, ransomware that overwrites all versions (requires MFA delete + Object Lock for full protection).
- **Security group audit:** Reviewed EC2 Public SG rules via CLI. Confirmed: no 0.0.0.0/0 on SSH (port 22), no open RDP (port 3389), no 0.0.0.0/0 on all ports (-1). Correct inbound: 80/443 from internet, 22 from specific management CIDR only.

## Artifacts Built Today
- [x] `memory/aws.md` — EC2, S3, VPC, IAM, CLI reference (committed in Day 06 main commit)
- [x] `daily-logs/day-06.md` — this file

## How I Used Claude Code Today
Hands-on practice day — worked through all 5 architecture extension steps using AWS CLI and Console. Claude served as the reference for CLI syntax, policy JSON structure, and architectural reasoning. Most valuable: the NAT Gateway explanation of exactly why private instances can initiate outbound but cannot receive inbound (no public IP + route table has no IGW entry for inbound). The S3 private bucket policy design (NotIpAddress + Deny effect overriding Allow) was counterintuitive — understanding the Deny override rule made the pattern click.

## Blockers / Questions for Mentor
- IRD-001 is now 10 days overdue. Does this need to be cleared before Day 7 content, or is the pattern now to treat it as a parallel-track artifact that follows the topic week it belongs to (Week 1 = Git, publish after Week 1 is complete)?
- NAT Gateway is running and billing. Should I delete it at end of each lab day and recreate it, or leave it running for Week 2 continuity? At $0.045/hr it costs ~$1.08/day.
- For the OpenVPN EC2 instance — same question. The Marketplace AMI instance costs money while running. Is there a stop/start pattern that works, or does the VPN config need to be reconfigured on restart?

## Self Score
- Completion: 8/10 (all 5 steps + explore further; carry-over still pending)
- Understanding: 9/10 (NAT Gateway traffic path and S3 Deny policy mechanics are now concrete)
- Energy: 8/10

## One Thing I Learned Today That Surprised Me

The S3 private bucket policy uses a `Deny` effect with `NotIpAddress` — not an `Allow` with `IpAddress`. This is backwards from what I expected. The reason it must be this way: if you use `Allow` with `IpAddress`, then requests from outside the VPC would fall through to the implicit deny at the bottom of the policy and be blocked. But IAM identity-based policies (attached to roles, users) can still grant access regardless of the bucket policy's Allow. The `Deny` effect with `NotIpAddress` is different — an explicit `Deny` in a resource-based policy overrides any `Allow` from any identity-based policy. It is absolute. This means even an `AdministratorAccess` IAM user cannot access the private bucket from outside the VPC. That's why production private buckets use Deny, not Allow.

---

## Tomorrow's Context Block

**Where I am:** End of Day 6 Extended, Week 2 — AWS Architecture Practice Lab complete. Full extended architecture built: Elastic IP on EC2 Public (static IP), NAT Gateway (private subnets have outbound internet), OpenVPN EC2 with EIP (direct SSH into private subnet without bastion), S3 public bucket (anonymous read via bucket policy), S3 private bucket (VPC-CIDR-only via Deny + NotIpAddress). memory/aws.md written and committed.

**What to do tomorrow (Day 7):** Check Day 7 training brief for next topic. Clear carry-over first if Day 7 has a light discovery chain: publish IRD-001 via `/write-ird`, create Linear training issue via `/create-linear-issue`, open `feat/w1-*` branch. Cost hygiene before starting: verify NAT Gateway + OpenVPN EC2 billing status.

**Open question:** IRD-001 is 10 days overdue — does it need to be cleared before Day 7 content, or is parallel-track publication acceptable?
