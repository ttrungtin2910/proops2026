# Topic: Cloud Concepts

**Last Updated:** 2026-04-08

---

## 1. Virtualization Stack

The stack runs from physical hardware up to the application process. Each layer abstracts the one below it.

```
Physical Hardware (CPU, RAM, NIC, NVMe)
        │
        ▼
Hypervisor (Type 1 or Type 2)
        │
        ▼
Virtual Machine (guest OS + kernel)
        │
        ▼
Container Runtime (Docker / containerd / runc)
        │
        ▼
Container (app process + filesystem snapshot)
```

### Layer Responsibilities

**Physical hardware**: raw compute, memory, storage, network. Managed by the data center or cloud provider. Never directly configurable in IaaS — you receive a virtualized view of it.

**Hypervisor**: intercepts hardware instructions from guest VMs and maps them to physical resources. Enforces isolation between VMs at the hardware level (Ring -1 on x86 via Intel VT-x / AMD-V). Two types:

| Type | Where it runs | Examples | Use case |
|---|---|---|---|
| Type 1 (bare metal) | Directly on hardware, no host OS | KVM, VMware ESXi, Hyper-V, Xen | Production clouds, data centers |
| Type 2 (hosted) | On top of a host OS | VirtualBox, VMware Workstation | Developer laptops, local testing |

Type 1 has lower overhead and better security isolation. Type 2 is convenient but adds a host OS as an extra layer of latency and attack surface. AWS EC2 uses KVM (Type 1). When recommending production infrastructure, always default to Type 1.

**Virtual Machine**: a complete OS running inside the hypervisor's resource allocation. Contains bootloader, kernel, full userspace (systemd, glibc, sshd, cron, device drivers), runtime, and application. Self-sufficient — can theoretically run on bare metal. The VM kernel communicates with what it believes is real hardware; the hypervisor translates.

**Container runtime**: software that creates and manages containers on the host OS (containerd, Docker Engine, CRI-O). The runtime calls Linux kernel primitives — `clone()`, `unshare()`, `mount()`, `execve()` — to set up namespace isolation and cgroup limits, then starts the containerized process.

**Container**: a process (or process tree) running on the host kernel, isolated via namespaces (what it can see) and constrained by cgroups (how much it can consume). The container image is a filesystem snapshot — not an OS. No kernel, no bootloader, no init system.

### Startup Time Comparison

| Layer | Startup time | Why |
|---|---|---|
| Physical server | 2–5 minutes | POST, BIOS, RAID initialization |
| VM (cold boot) | 30–120 seconds | Full boot sequence: firmware → GRUB → kernel decompress → systemd → services |
| VM (from snapshot) | 5–15 seconds | Skips boot, restores memory state |
| Container | 100–500ms | No boot sequence — just kernel syscalls to set up namespaces + exec the process |

Container startup speed is why Kubernetes can autoscale in seconds while VM-based autoscaling takes 2–5 minutes per new instance.

### Image Size Comparison

| Unit | Typical size | What's inside |
|---|---|---|
| VM image | 5–20 GB | Bootloader, kernel (~200MB), full OS userspace (~800MB), all system services, runtime, app dependencies, pre-allocated disk headroom |
| Container image | 10 MB – 1 GB | Only the filesystem: base OS layer (glibc, libssl), runtime, app dependencies, application code. No kernel, no bootloader, no init system. |

A Node.js application: ~150MB container image vs ~8GB VM image. Difference is entirely the OS infrastructure that containers borrow from the host kernel.

### When to Use VM vs Container

Use a **VM** when:
- Strong isolation is required between mutually untrusting workloads (multi-tenant public cloud, regulated data)
- The workload requires a different kernel version or OS than the host
- The application uses kernel modules, specific kernel parameters, or OS-level configuration that a container cannot expose
- Compliance requires OS-level audit logging (auditd, SELinux enforcement at kernel level)
- The workload is long-running and startup latency is irrelevant

Use a **container** when:
- The workload is stateless or manages state externally (RDS, S3, Redis)
- Fast scaling is required (autoscaling, batch jobs, CI runners)
- Multiple services need to run on the same host with resource isolation but not full OS isolation
- The team wants a reproducible, portable artifact that runs identically in dev and prod
- Kubernetes is the deployment target

---

## 2. VM vs Container Isolation

### Side-by-Side Comparison

| Dimension | VM | Container |
|---|---|---|
| **Isolation mechanism** | Hypervisor enforces hardware boundary (Ring -1). Guest kernel is fully separated from host kernel. | Linux namespaces (visibility) + cgroups (resource limits). Process shares host kernel directly. |
| **Isolation strength** | Strong — to escape, attacker must exploit the hypervisor (~13,000 lines of KVM code) | Weaker by default — attacker can reach host kernel via any of ~400 syscalls; kernel CVE = host compromise |
| **Startup time** | 30–120 seconds (full OS boot) | 100–500ms (namespace + exec syscalls only) |
| **Image size** | 5–20 GB (full OS required) | 10 MB – 1 GB (filesystem snapshot only) |
| **Portability** | Tied to hypervisor format (VMDK, QCOW2, VHD) — not trivially portable between providers | OCI image format is universal — runs identically on any container runtime on any Linux host |
| **Security boundary** | Hardware-enforced. Kernel exploit in VM stays inside VM. | Software-enforced. Unpatched host kernel CVE affects all containers on host simultaneously. |
| **Density per host** | Lower — each VM runs a full OS consuming 1–4 GB RAM at idle | Higher — containers share the host kernel; a Node.js container may idle at 50MB RAM |
| **Right choice** | Multi-tenant isolation, regulated workloads, different OS/kernel requirements | Same-OS workloads, Kubernetes, fast scaling, CI/CD, microservices |

### Namespace Details (what each namespace isolates)

| Namespace | Isolates | Concrete effect |
|---|---|---|
| `pid` | Process IDs | Container sees its app as PID 1; cannot see or kill host processes |
| `net` | Network stack | Container gets own virtual NIC, IP, routing table |
| `mnt` | Filesystem mounts | Container sees its own root filesystem; cannot see host `/etc`, `/home` |
| `uts` | Hostname + domain | Container can have hostname `api-server` while host is `prod-node-07` |
| `user` | UID/GID mapping | UID 0 inside container maps to unprivileged UID on host (rootless containers) |

### Cgroup Resource Controls

Cgroups enforce hard limits. The kernel enforces them — they are not suggestions.

```
cgroup: container-A
├── cpu.max = 500000/1000000     → max 0.5 CPU cores
├── memory.max = 512M            → OOM-killed if exceeded
├── blkio.weight = 100           → disk I/O priority
└── pids.max = 200               → fork bomb prevention
```

Kubernetes `resources.limits` is a YAML interface to cgroup entries. Setting `cpu: "500m"` writes `500000/1000000` to the container's `cpu.max` cgroup file.

### Container Security Controls (production required)

| Control | What it does |
|---|---|
| `seccomp` | BPF filter on syscall interface — blocks the ~300 syscalls your app never needs. Docker default blocks ~44; a custom profile blocks 300+. |
| `AppArmor` / `SELinux` | Mandatory Access Control — defines which files, capabilities, and network operations the process may use. Defense-in-depth if namespace isolation is bypassed. |
| Drop all capabilities | `--cap-drop=ALL --cap-add=NET_BIND_SERVICE` — prevents compromise from loading kernel modules, bypassing DAC, or calling `ptrace`. |
| Rootless containers | Run runtime and container as non-root host user — escape lands as UID 1000 with no privileges. |
| Read-only root filesystem | `--read-only` — blocks attacker from writing new binaries or persisting changes. |
| No `--privileged`, no Docker socket mount | Privileged containers have full host access. Docker socket mount = root on host. Enforce via K8s admission controller (Kyverno / OPA Gatekeeper). |
| gVisor / Kata Containers | Sandboxed kernel (gVisor) or lightweight VM per pod (Kata) — restores VM-level isolation with container-level startup speed. Use for multi-tenant workloads. |

---

## 3. IaaS / PaaS / SaaS

### Shared Responsibility Stack

```
Layer                  IaaS              PaaS              SaaS
─────────────────────────────────────────────────────────────────
Application code       YOU               YOU               PROVIDER
App configuration      YOU               YOU               PROVIDER
Data + backups         YOU               YOU               SHARED*
Runtime                YOU               PROVIDER          PROVIDER
Middleware             YOU               PROVIDER          PROVIDER
OS patching            YOU               PROVIDER          PROVIDER
OS installation        YOU               PROVIDER          PROVIDER
Virtualization         PROVIDER          PROVIDER          PROVIDER
Physical servers       PROVIDER          PROVIDER          PROVIDER
Network fabric         PROVIDER          PROVIDER          PROVIDER
─────────────────────────────────────────────────────────────────
* SaaS: provider stores data, you own its contents and access control.
  Compliance obligations (GDPR, HIPAA) stay with you.
```

### Real Examples by Layer

| Service model | AWS example | Azure example | What you deploy |
|---|---|---|---|
| IaaS | EC2 + VPC + EBS | Azure Virtual Machines + VNet | Raw VM — you install everything |
| PaaS | Elastic Beanstalk, App Runner, RDS | Azure App Service, Azure SQL | App code or container image |
| SaaS | Datadog, Snowflake, GitHub | Microsoft 365, Azure DevOps (hosted) | Configuration only |

### DevOps Implications by Layer

**IaaS (EC2)**
- Team size: 2–3 dedicated infra/DevOps engineers minimum for production
- Skills required: Linux sysadmin, networking (VPC, SG, routing), configuration management (Ansible/Terraform), monitoring setup (CloudWatch agent), OS patching process
- Operational overhead: high — you own the full lifecycle of every resource
- Right choice when: you need OS-level control, custom kernel parameters, compliance requiring audit at OS level, or workloads that don't fit PaaS constraints

**PaaS (Elastic Beanstalk, App Service)**
- Team size: 1 engineer who understands AWS + your deployment process; product engineers can own it part-time
- Skills required: platform-specific config (`.ebextensions`), understanding what the platform provisions underneath, data management (PaaS doesn't manage your database)
- Operational overhead: low for standard workloads; medium when you hit platform constraints
- Right choice when: your app fits the platform's model (standard web/API/worker), team's core competency is the application not infrastructure, need to ship fast without a DevOps hire

**SaaS**
- Team size: 0 dedicated infra headcount; handled by developer or IT admin part-time
- Skills required: account/access management, integration config, vendor risk assessment (data residency, SLA, lock-in)
- Operational overhead: near-zero for infrastructure; vendor relationship and contract management instead
- Right choice when: capability is not your core product (auth, email, payments, monitoring, analytics), build cost > buy cost

### What PaaS Does That You'd Have to Build on IaaS (concrete)

Using Node.js API on EC2 vs Elastic Beanstalk as the example:

| Task | EC2 (you build) | Elastic Beanstalk (provider does) |
|---|---|---|
| Runtime installation | user-data script or Ansible playbook | Included in platform spec |
| Zero-downtime deploy | CodeDeploy lifecycle or custom rolling pipeline | `eb deploy` |
| Auto Scaling + health replacement | ASG + launch template + ELB target group | Config file |
| Log aggregation to CloudWatch | Install CloudWatch agent, write config, IAM role | Toggle in `.ebextensions` |
| OS patching | Your process, your schedule | Platform version update |
| Secret injection | SSM Parameter Store + startup hook | Env var UI / CLI |
| Time to production (new service) | 2–5 days | 2–4 hours |

---

## 4. Availability Zones and High Availability

### What an AZ Is

An Availability Zone is one or more physically separate data center buildings within a region, with independent:

- **Power**: separate utility grid feed, substation, on-site diesel generators, UPS banks
- **Cooling**: separate chiller plants; a cooling failure in one AZ does not cascade
- **Networking**: separate routers, switches, fiber paths, upstream transit links; each AZ has its own Internet gateway
- **Physical location**: geographically separated within a metropolitan area — no shared blast radius for localized physical events

Inter-AZ latency within a region: ~1–2ms round trip. Inter-AZ links are dedicated low-latency fiber, not public internet.

A region (e.g. `us-east-1`) typically has 3–6 AZs. AZ names (`us-east-1a`, `us-east-1b`, `us-east-1c`) are mapped randomly per AWS account — `us-east-1a` in your account is not the same physical AZ as `us-east-1a` in another account.

### What Multi-AZ Protects Against

| Failure scenario | Single-AZ result | Multi-AZ result |
|---|---|---|
| AZ power outage (substation failure) | Full service outage until power restored | ALB detects unhealthy targets in ~30s, routes to healthy AZs |
| Localized flooding / physical damage | Catastrophic loss; recovery from backup | Other AZs unaffected; RDS standby promotes in ~60s |
| Batch hardware failure (bad EBS firmware) | Your volumes may be affected | Only affected AZ's volumes impacted; replicas in other AZs unaffected |
| AZ network partition (fiber cut) | Complete outage even if instances are healthy | Traffic routes through other AZs' network paths |
| AWS software bug in AZ infrastructure | All your instances impaired simultaneously | Impact limited to one AZ; service stays up on healthy AZs |

### What Multi-AZ Does NOT Protect Against

Multi-AZ protects against AZ-scoped failures only. Region-scoped failures take down all AZs simultaneously:

- **Regional control plane failures**: EC2, RDS, IAM, and other service APIs have regional control planes. A software bug in the `us-east-1` EC2 control plane can prevent launching instances, modifying security groups, or triggering Auto Scaling across all AZs — even if running instances are healthy. (Example: AWS us-east-1 December 2021 outage.)
- **Regional DNS failures**: Route 53 regional issues prevent DNS resolution regardless of how many AZs your servers are in.
- **Region-wide networking events**: BGP routing leak or upstream exchange failure degrading connectivity to an entire region.
- **Region-wide software updates**: bad AMI, broken AWS-managed kernel update, or flawed agent pushed region-wide.

**Protection scope hierarchy:**

```
Multi-AZ:      AZ hardware, power, cooling, localized network, AZ-scoped software bugs
Multi-Region:  Regional control plane, regional network, regional software bugs
Multi-Cloud:   Cloud provider incidents, provider regulatory/legal events
```

Multi-region is justified only when the SLA target cannot be met by multi-AZ and when the 3–5x operational complexity and 2–3x cost are justified by the business case.

### Trade-offs of Multi-AZ

**Latency**
- Inter-AZ traffic adds ~1–2ms vs intra-AZ
- Visible in: synchronous DB writes with Multi-AZ replication (every write waits for standby acknowledgment), microservices with chatty cross-AZ calls (20 synchronous calls × 2ms = 40ms added per request)
- Mitigation: collocate latency-sensitive synchronous calls within an AZ; replicate asynchronously where consistency allows; use ALB with AZ affinity for same-AZ routing where safe

**Data consistency**
- Synchronous replication (RDS Multi-AZ default): write confirmed in both AZs before returning. Consistency guaranteed; write latency and throughput reduced.
- Asynchronous replication (Aurora read replicas, ElastiCache): write returns immediately; replica catches up asynchronously. Replication lag = potential data loss window on failover.
- Decision: "What is the maximum acceptable data loss window?" drives replication mode selection per data store.

**Cost**
| Component | Single-AZ | Multi-AZ |
|---|---|---|
| RDS | 1 instance | 2 instances (primary + standby) — ~2x cost |
| EC2 compute | N instances, 1 AZ | N instances, 3 AZs — requires ALB |
| ALB | Optional | Required — ~$16/month base + LCU |
| NAT Gateway | 1 optional | 1 per AZ for private subnets — ~$32/month each |
| Inter-AZ data transfer | Free | ~$0.01/GB each direction |

The inter-AZ data transfer charge is the non-obvious cost. High-throughput services moving large payloads between AZs accumulate real monthly charges.

**Operational complexity**
- Subnet design: 1 subnet per AZ per tier minimum. 3 AZs × 3 tiers (public, private, data) = 9 subnets
- Failover testing: must periodically validate by terminating instances in one AZ — untested HA is theater
- Stateful services each have distinct failover mechanics: RDS (~60s, DNS cutover), ElastiCache, MSK partition leader reassignment
- Deployment must target all AZs consistently — partial deploys require backward-compatible API design

---

## 5. Cloud Cost Mechanics

### The Three Biggest Sources of Surprise Bills

#### Source 1: Data Transfer Costs

**What it is**: AWS charges for data movement in several categories:
- EC2 inter-AZ transfer: ~$0.01/GB each direction
- NAT Gateway data processing: ~$0.045/GB for all traffic routed through NAT (plus inter-AZ charge if EC2 and NAT Gateway are in different AZs)
- EC2 to internet (egress): ~$0.09/GB
- Cross-region transfer: ~$0.02/GB

**Common cause of spike**: misconfigured routing table sends intra-VPC traffic through NAT Gateway; a new feature starts downloading large external payloads; a service moves from same-AZ to cross-AZ communication pattern.

**Monitoring signal**: `AWS/NATGateway → BytesOutToDestination` and `AWS/EC2 → NetworkOut` in CloudWatch. If `NetworkOut` on EC2 instances is flat but NAT Gateway bytes spiked on a specific date, traffic routing changed — check route tables. Set a CloudWatch Alarm with anomaly detection on `BytesOutToDestination`.

#### Source 2: Over-Provisioned or Forgotten Running Resources

**What it is**:
- EC2 instances left running after testing (an `m5.2xlarge` = ~$275/month indefinitely)
- Auto Scaling launched large instances during a peak and never scaled back down
- RDS instances left in `available` state after a demo (a `db.r5.2xlarge` Multi-AZ = ~$700/month)
- ALBs from decommissioned services (~$16/month base, zero requests)

**Monitoring signal**: `AWS/ApplicationELB → RequestCount` — an ALB with zero requests for 7+ days is orphaned. `AWS/EC2 → CPUUtilization` — instances consistently below 5% CPU are candidates for termination. AWS Compute Optimizer generates automated right-sizing recommendations; review weekly.

**Investigation commands**:
```bash
# Find EC2 instances running with low CPU (use Compute Optimizer)
aws compute-optimizer get-ec2-instance-recommendations \
  --query 'instanceRecommendations[?finding==`OVER_PROVISIONED`].[instanceArn,finding]'

# Find unattached EBS volumes
aws ec2 describe-volumes \
  --filters Name=status,Values=available \
  --query 'Volumes[*].[VolumeId,Size,CreateTime]' \
  --output table

# Find unassociated Elastic IPs
aws ec2 describe-addresses \
  --query 'Addresses[?AssociationId==null].[PublicIp,AllocationId]' \
  --output table
```

#### Source 3: Forgotten Snapshots and Static Storage

**What it is**:
- EBS snapshots: $0.05/GB/month. A daily snapshot policy on a 1TB volume with no expiry creates ~$50/month in new charges per cycle. Six months without cleanup = $300/month from snapshots on one volume alone.
- EBS volumes not attached to instances: `DeleteOnTermination` defaults to `true` for root volumes but `false` for additional volumes — detached volumes bill indefinitely.
- Old AMIs: the AMI itself is free but its backing EBS snapshots are not. 200 old CI build AMIs can represent TBs of snapshot storage.
- S3 storage growth without lifecycle policies: application logs, build artifacts, backups accumulate without bound if no expiry is configured.

**Monitoring signal**: In Cost Explorer, group by `Usage Type` and watch `EBS:SnapshotUsage` and `AmazonS3 → BucketSizeBytes` as a weekly trend. A step-change increase on a specific date means something started writing more data or a lifecycle policy stopped working. Set a Cost Anomaly Detection alert at +20% week-over-week for these line items.

**Investigation commands**:
```bash
# Find EBS snapshots older than 90 days
aws ec2 describe-snapshots --owner-ids self \
  --query 'Snapshots[?StartTime<=`2025-10-01`].[SnapshotId,VolumeSize,StartTime]' \
  --output table

# Find S3 buckets without lifecycle policies
aws s3api list-buckets --query 'Buckets[*].Name' --output text | \
  xargs -I{} aws s3api get-bucket-lifecycle-configuration --bucket {} 2>&1 | \
  grep -E "NoSuchLifecycleConfiguration|bucket"
```

### Cost Investigation Procedure

When a bill spikes unexpectedly:

1. **Open Cost Explorer → Daily costs, grouped by Service**. Find the exact date costs diverged from prior month baseline. That date is your anchor.
2. **Re-group by Usage Type** within the offending service. This identifies what *kind* of usage drove the cost (e.g., `DataTransfer-Regional-Bytes` vs `BoxUsage:m5.4xlarge`).
3. **Cross-reference the spike date** with CloudWatch metrics for the relevant service. Traffic spike + cost spike = legitimate load. Flat traffic + cost spike = resource or routing change.
4. **Run the investigation commands** above to enumerate idle and orphaned resources.

### Weekly Cost Hygiene Checklist

Run these five checks every Monday. Monthly checks arrive after the damage is done.

| Check | Tool | Time | What you're looking for |
|---|---|---|---|
| 1. Anomaly Detection alerts | AWS Cost Anomaly Detection console | 5 min | Any triggered alert from past 7 days above $50 or 20% threshold |
| 2. Idle resource scan | AWS Compute Optimizer + CLI commands above | 15 min | EC2 <5% CPU, unattached EBS volumes, unassociated EIPs, ALBs with zero requests |
| 3. Storage growth check | Cost Explorer → EBS:SnapshotUsage + S3 BucketSizeBytes trend | 10 min | Step-change increase on a specific date indicating missing lifecycle policy |
| 4. Budget alert status | AWS Budgets console | 2 min | Any budget in ALERT or EXCEEDED state (budgets should be set at 110% of prior month per service) |
| 5. New resource tagging audit | AWS Tag Editor — filter resources created in past 7 days missing Owner/Environment/Project tags | 10 min | Untagged resources have no owner — nobody is accountable when they become idle |

**Enable these proactively** (one-time setup):
- AWS Cost Anomaly Detection with SNS alert at +$50 or +20% per service
- AWS Budgets per major service at 110% of prior month spend
- S3 lifecycle policies on every bucket that receives logs, artifacts, or backups (transition to Glacier at 30 days, expire at 90 days as a safe default)
- `DeleteOnTermination = true` on all EBS volumes at launch time

---

## Key Commands / Config Patterns

```bash
# Cost Explorer: run an ad-hoc cost query by service and usage type
# (Use the AWS Console Cost Explorer UI — CLI equivalent is get-cost-and-usage)
aws ce get-cost-and-usage \
  --time-period Start=2026-03-01,End=2026-04-01 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Find all running EC2 instances with launch time and name tag
aws ec2 describe-instances \
  --filters Name=instance-state-name,Values=running \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,LaunchTime,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Enable Cost Anomaly Detection (do this once per account)
aws ce create-anomaly-monitor \
  --anomaly-monitor '{"MonitorName":"AllServices","MonitorType":"DIMENSIONAL","MonitorDimension":"SERVICE"}'
```

```yaml
# Kubernetes resource limits — maps to cgroup entries on the node
resources:
  requests:
    cpu: "250m"      # Scheduler uses this for bin-packing decisions
    memory: "256Mi"  # Scheduler uses this for bin-packing decisions
  limits:
    cpu: "500m"      # Writes cpu.max = 500000/1000000 to cgroup
    memory: "512Mi"  # OOM-killer fires if container exceeds this
```

---

## Common Gotchas

- **AZ names are not canonical across accounts**: `us-east-1a` in your account is not the same physical AZ as `us-east-1a` in a colleague's account. AWS maps AZ names randomly per account to distribute load. Use AZ IDs (`use1-az1`) for cross-account AZ coordination.
- **Elastic Beanstalk is free; what it creates is not**: EB charges nothing itself, but it provisions EC2, ALB, Auto Scaling Groups, and CloudWatch under your account. Understand what it created before assuming the cost model.
- **Inter-AZ NAT Gateway double-charge**: if your EC2 instance is in AZ-a and the NAT Gateway is in AZ-b, you pay inter-AZ transfer ($0.01/GB) *plus* NAT Gateway processing ($0.045/GB). Always deploy one NAT Gateway per AZ and configure route tables so each AZ's private subnets route to the local NAT Gateway.
- **`DeleteOnTermination` is false for non-root EBS volumes**: additional data volumes attached at launch time persist after instance termination unless explicitly set. Set `DeleteOnTermination=true` for ephemeral workloads at launch configuration time, not after the fact.
- **RDS Multi-AZ failover is DNS-based**: the failover promotes the standby and updates the CNAME endpoint, which takes ~60 seconds to propagate. Applications that cache DNS or use the IP directly will not automatically reconnect. Ensure connection strings use the RDS endpoint hostname and that the application handles reconnection after TCP reset.
- **Containers share host kernel — patch the host, not just the image**: updating a container image does not patch the host kernel. A kernel CVE affecting all containers on a node requires patching the node's OS, not rebuilding the image.

---

## Architecture Decision Rules (agent use)

When recommending compute deployment model:
1. **Default to containers on Kubernetes** for stateless services, APIs, and workers. They provide the right density, portability, and scaling characteristics for most production workloads.
2. **Recommend VMs** when: OS-level configuration is required, workloads are mutually untrusting, compliance mandates kernel-level audit logging, or the application uses kernel features containers cannot expose.
3. **Recommend PaaS** when: the team has no dedicated DevOps engineer, the app fits the platform model, and time-to-production is a priority over control.
4. **Always recommend multi-AZ** for production. Single-AZ is acceptable only for non-production environments.
5. **Recommend multi-region** only when: the business SLA requires >99.99% availability AND the engineering team can support the operational overhead AND the cost is justified.
6. **Flag missing cost controls** in any architecture review: if a design lacks Cost Anomaly Detection, resource tagging policy, or S3 lifecycle policies, call it out as an operational gap.

---

## Links to Related Memory Files

- See also: `memory/docker.md` — container image building, layering, and runtime configuration
- See also: `memory/kubernetes-core.md` — container orchestration, cgroup limits via resource specs, AZ-aware scheduling
- See also: `memory/networking-basics.md` — VPC design, subnets, routing tables, NAT Gateway placement
- See also: `memory/software-architecture.md` — scaling models per architecture pattern, which patterns map to which compute models
