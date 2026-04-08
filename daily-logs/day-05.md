# Daily Log — Tin (Trần Trung Tín) — Day 5 — 2026-04-08

## Today's Assignment
- [x] Watch training session recording (from 1:02:00, ~90 min)
- [x] Q1 — Virtualization: why "buy a bigger server" doesn't solve resource flexibility; hypervisor + resource isolation; economic argument for multi-VM on single host
- [x] Q2 — Hypervisor mechanics: Type 1 vs Type 2, CPU oversubscription model, AWS noisy-neighbor mitigation
- [x] Q3 — VM vs container isolation: namespaces + cgroups deep dive, why container is 50x smaller, startup time difference
- [x] Q4 — Security auditor question: honest isolation comparison, shared-kernel attack surface, container escape classes, production mitigations
- [x] Q5 — IaaS / PaaS / SaaS: shared responsibility stack at each layer, team size implications, EC2 vs Beanstalk concrete comparison
- [x] Q6 — Availability Zones: physical AZ definition, what multi-AZ protects against, what it does NOT protect against, latency/cost/complexity trade-offs
- [x] Q7 — Cloud cost investigation: three causes of surprise bills, monitoring signals for each, weekly hygiene checklist
- [x] Q8 — Write memory/cloud-concepts.md (5 required sections)

## Environment
Theory day — no terminal required. All work done inside Claude Code in proops2026/ folder.

## Completed

- [x] **Q1: Why virtualization, not a bigger server** — Core insight: physical resources are fixed, virtual allocation is flexible. A single 32-core server running 8 VMs with CPU oversubscription achieves better utilization than 8 separate servers at 10% utilization each. The hypervisor is a software scheduler: it presents virtual hardware to guest OSes and multiplexes physical hardware across VMs. Economic argument: one physical host at 80% utilization serves 8 workloads; 8 separate servers at 10% utilization each wastes 72% of capacity and multiplies every operational cost (power, cooling, licensing, patching).

- [x] **Q2: Hypervisor mechanics + oversubscription** — Type 1 (bare metal): runs directly on hardware, no host OS layer — KVM, VMware ESXi, Xen, Hyper-V. AWS EC2 uses KVM (Type 1) with their custom Nitro hypervisor. Type 2 (hosted): runs on top of a host OS — VirtualBox, VMware Workstation. Oversubscription: 12 VMs × 4 vCPUs = 48 vCPUs on 32 physical cores is possible because VMs are rarely all at 100% simultaneously. Risk: when all 12 spike, CPU scheduler must time-slice — each VM gets less than its allocated vCPUs. Mitigation: AWS uses burstable instance types (T-series) with CPU credits for predictable workloads; dedicated hosts and placement groups for workloads requiring guaranteed physical resources. Nitro hypervisor moves network and storage to dedicated hardware offload cards, giving EC2 instances near-bare-metal I/O performance.

- [x] **Q3: VM vs container isolation — deep dive** — VM: guest OS kernel talks to virtual hardware fabricated by hypervisor; hypervisor intercepts hardware instructions via Intel VT-x / AMD-V (Ring -1). Complete isolation: kernel exploit inside VM must escape hypervisor (~13k lines of KVM code) to reach host. Container: no kernel, no bootloader — shares host kernel directly. Isolation = namespaces (visibility filter) + cgroups (resource enforcement). Namespaces: pid (PID 1 isolation), net (own IP/NIC), mnt (own root filesystem), uts (own hostname), user (UID remapping). Cgroups: cpu.max, memory.max, pids.max — kernel-enforced hard limits. Size difference: VM image = full OS (bootloader 5MB + kernel 200MB + userspace 800MB + services + runtime + app = 10GB). Container image = filesystem only (base 30MB + runtime 60MB + deps 80MB + code 30MB = ~200MB). Startup: VM must replay full boot sequence (firmware → GRUB → kernel decompress → systemd → services = 30–60s). Container = kernel syscalls only (clone() + unshare() + mount() + execve() = 100–500ms).

- [x] **Q4: Security auditor answer** — Honest answer: containers are less isolated than VMs. Reason: containers share the host kernel — any exploitable kernel CVE affects all containers on the node simultaneously. VM attack surface is the hypervisor; container attack surface is the entire host kernel (~400 syscalls). Container escape class: privileged container abuse (mounting host filesystem, accessing Docker socket, CAP_SYS_ADMIN exploitation). Production mitigations: `seccomp` (BPF syscall filter, Docker default blocks ~44 syscalls; custom profiles block 300+), `AppArmor`/`SELinux` (Mandatory Access Control — defines allowed file paths, capabilities, network ops), drop all capabilities (`--cap-drop=ALL --cap-add=NET_BIND_SERVICE`), rootless containers (escape lands as UID 1000 on host), read-only root filesystem. For multi-tenant workloads: gVisor (sandboxed kernel per container) or Kata Containers (lightweight VM per pod = container API, VM isolation strength).

- [x] **Q5: IaaS / PaaS / SaaS shared responsibility** — IaaS (EC2): I manage OS patching, runtime, middleware, config, networking, monitoring agent installation, scaling logic, secret injection. Team requirement: 2–3 dedicated DevOps engineers. PaaS (Elastic Beanstalk): I manage only app code, configuration, and data. Platform does runtime installation, zero-downtime deploy, ASG + ALB wiring, log aggregation, OS patching. Team requirement: 1 engineer part-time. Concrete EC2 vs EB comparison for Node.js API: EB handles auto-scaling group + launch template + ELB target group wiring (2–5 days on EC2 → 2–4 hours on EB), zero-downtime deploys, log aggregation to CloudWatch. SaaS: configuration only; 0 infra headcount. Right choice criteria: IaaS = need OS-level control or compliance; PaaS = standard workload, ship fast, no dedicated DevOps; SaaS = capability is not your core product.

- [x] **Q6: Availability Zones + HA design** — AZ = one or more physically separate data center buildings within a region with independent power (separate utility grid + diesel generators + UPS), cooling (separate chiller plants), networking (separate routers, fiber paths, upstream transit links). Inter-AZ latency: ~1–2ms. What multi-AZ protects: AZ power outage, localized flooding, batch hardware failure, AZ network partition, AZ-scoped software bugs. What multi-AZ does NOT protect: regional control plane failures (EC2/IAM/RDS APIs have regional control planes — AWS us-east-1 Dec 2021 is the canonical example), regional DNS failures, region-wide software updates pushed to all AZs. Trade-offs: latency (+1–2ms per cross-AZ call; 20 synchronous calls = +40ms), data consistency (synchronous replication = confirmed in both AZs, lower write throughput; async = replication lag = data loss window), cost (RDS Multi-AZ ~2x cost, 1 NAT Gateway per AZ at ~$32/month each, inter-AZ data transfer at $0.01/GB).

- [x] **Q7: Cloud cost investigation** — Cause 1: data transfer costs — EC2 inter-AZ $0.01/GB each direction; NAT Gateway processing $0.045/GB; egress to internet $0.09/GB. Monitoring signal: `AWS/NATGateway → BytesOutToDestination` spike on a date when traffic was flat = routing change (check route tables). Cause 2: over-provisioned or forgotten running resources — EC2 left running after testing ($275/month for m5.2xlarge), RDS in `available` state after a demo ($700/month for db.r5.2xlarge Multi-AZ). Signal: ALB with zero `RequestCount` for 7+ days = orphaned; EC2 consistently <5% CPUUtilization = right-sizing candidate; use `aws compute-optimizer get-ec2-instance-recommendations`. Cause 3: forgotten snapshots and static storage — EBS snapshots at $0.05/GB/month; daily snapshots without expiry on a 1TB volume = ~$50/month new charges per cycle. Signal: Cost Explorer `EBS:SnapshotUsage` step-change on a date = lifecycle policy stopped working. Weekly hygiene: Cost Anomaly Detection alerts, idle resource scan (Compute Optimizer), storage growth trend, Budget alert status, new resource tagging audit.

- [x] **Q8: memory/cloud-concepts.md written** — 5 required sections: Virtualization Stack (layer diagram + startup/size tables + VM vs container decision criteria), VM vs Container Isolation (side-by-side table + namespace details + cgroup config + production security controls), IaaS/PaaS/SaaS (shared responsibility stack + AWS/Azure examples + DevOps implications + EC2 vs EB concrete comparison), Availability Zones and HA (AZ physical definition + failure scenario matrix + trade-offs table + cost breakdown), Cloud Cost Mechanics (three surprise bill sources with monitoring signals + investigation commands + weekly hygiene checklist). Written for agent consumption: includes architecture decision rules and links to related memory files.

## Not Completed
| Item | Reason | Days Overdue |
|---|---|---|
| Publish IRD-001 to Notion | Session time consumed by discovery chain depth | 4 days |
| Create Linear training issue | Blocked on IRD-001 publication | 4 days |
| Open feat/w1-* branch | Blocked on Linear issue creation | 4 days |

## Extra Things Explored (Explore Further)

**VM vs Container Isolation — implementation detail** (prompted by Q3 depth):
- Namespace creation mechanics: `clone(CLONE_NEWPID | CLONE_NEWNET | CLONE_NEWNS | CLONE_NEWUTS)` — the kernel creates new namespace instances in a single syscall
- OverlayFS union mount: container image layers are stacked using OverlayFS; lower layers are read-only, upper layer is a writable copy-on-write layer per container; this is why two containers from the same image share the image bytes on disk
- Cgroup v1 vs v2: cgroup v2 (unified hierarchy) is the default since Linux 5.2 and is what modern container runtimes and Kubernetes target. Single-hierarchy model vs cgroup v1's per-controller hierarchy — simplifies container resource accounting significantly
- K8s `resources.requests` vs `resources.limits`: requests are used by the scheduler for bin-packing decisions (which node has room); limits map to cgroup entries on the node. A pod with `requests.cpu=250m` and `limits.cpu=500m` will be scheduled assuming 250m of available capacity but can burst to 500m if the node has headroom

**Virtualization and translation (language bridge):**
- Full technical translation of the VM vs Container deep-dive content into Vietnamese, preserving all technical terms, diagrams, and mental models — useful for explaining these concepts to Vietnamese-speaking engineers or in mixed-language team documentation.

## Artifacts Built Today
- [x] `memory/cloud-concepts.md` — new file: 5 sections covering virtualization stack, VM vs container isolation, IaaS/PaaS/SaaS, Availability Zones, cloud cost mechanics. Written for agent consumption with architecture decision rules and monitoring commands throughout.

## How I Used Claude Code Today
Theory day — worked through all 8 discovery questions as a continuous mental model build from physical hardware up to cloud cost. Q3 (VM vs container) and Q4 (security) were the densest — pushed past surface-level answers to get to the actual mechanism (namespace/cgroup syscalls, seccomp BPF filter, hypervisor ring levels). Also requested a full Vietnamese translation of the Q3 deep-dive material to reinforce understanding and bridge language context. Claude framed every answer around the progression from physical → virtual → container → cloud, which made the concepts stack coherently rather than feel disconnected.

## Blockers / Questions for Mentor
- IRD-001 is now 4 days overdue. Day 6 recommendation: should I block on carry-over tasks first thing, or is there an acceptable path to treat the IRD/Linear/branch tasks as a parallel track that doesn't block content progression?
- On the `Private_Dirty` memory question from Day 4 (carried forward): does container `memory.max` cgroup enforcement account for page cache, shared mappings, or only anonymous/dirty pages? The distinction matters when tuning K8s `memory.limits` for applications that do heavy file I/O.
- For gVisor (sandboxed kernel per container) — is this used in any AWS-managed service, or is it only relevant for self-managed K8s clusters? Trying to understand when I'd actually configure this vs default containerd.

## Self Score
- Completion: 8/10 (all 8 Qs + memory file done; carry-over still pending)
- Understanding: 9/10 (namespace/cgroup model is now concrete, not abstract)
- Energy: 8/10

## One Thing I Learned Today That Surprised Me

AZ names are not canonical across AWS accounts. `us-east-1a` in my account is not the same physical data center as `us-east-1a` in a colleague's account. AWS maps AZ names randomly per account to distribute load across physical facilities. The physical identifier is the AZ ID (`use1-az1`), which is consistent. This means: if you're coordinating multi-account architecture (e.g., shared VPC, cross-account peering, reserved capacity) and you assume `us-east-1a` means the same physical location for both accounts, you will get the topology wrong. Use AZ IDs when the physical location matters.

---

## Tomorrow's Context Block

**Where I am:** End of Day 5, Week 1 — Virtualization + Cloud Concepts completed. All 8 discovery questions done plus Explore Further. Artifact: `memory/cloud-concepts.md` with 5 sections (virtualization stack, VM vs container isolation, IaaS/PaaS/SaaS, AZs, cost mechanics). Carry-over from Day 3 still open: IRD-001 unpublished, no Linear issue, no `feat/w1-*` branch.

**What to do tomorrow (Day 6):** Clear carry-over first — this is now blocking. Publish IRD-001 via `/write-ird`, create Linear training issue via `/create-linear-issue`, open `feat/w1-*` branch. Then start Day 6 topic (check training plan for Week 1 Day 6 assignment).

**Open question:** Does container `memory.max` cgroup enforcement account for page cache and shared mappings, or only anonymous dirty pages? Relevant for tuning K8s `memory.limits` on file-I/O-heavy workloads.
