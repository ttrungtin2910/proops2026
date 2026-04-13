# AWS Reference for DevOps Agents

**Last Updated:** 2026-04-13

This file covers the AWS primitives a DevOps engineer touches daily: EC2, S3, VPC, IAM, and the CLI patterns that tie them together. It is written for agent consumption — use it to provision infrastructure, debug access failures, and design network topology without reaching for general knowledge.

---

## 1. EC2 Instance Lifecycle

### Instance States

```
run-instances
      │
      ▼
  [pending]  ← AWS allocating hardware, copying AMI, running user-data
      │
      ▼
  [running]  ← reachable, billing active for compute
      │  ├──────── stop ──────────────────────────────────────────────┐
      │  │                                                             ▼
      │  │                                                        [stopping]
      │  │                                                             │
      │  │                                                             ▼
      │  │                                                         [stopped]  ← EBS persists, no compute charge
      │  │                                                             │
      │  │                                           start ───────────┘
      │  │
      │  └──────── terminate ──────────────────────────────────────┐
      │                                                             ▼
      │                                                       [shutting-down]
      │                                                             │
      │                                                             ▼
      └─────────────────────────────────────────────────────> [terminated]  ← irreversible; EBS deleted by default
```

### What Persists vs What Is Lost

| Event | EBS root volume | Additional EBS volumes | Elastic IP | Instance store (NVMe) | RAM / ephemeral state |
|-------|----------------|----------------------|------------|----------------------|----------------------|
| **Stop → Start** | Persists | Persists | Persists if associated | **Lost** (wiped on stop) | Lost |
| **Reboot** | Persists | Persists | Persists | Persists | Lost |
| **Terminate** | **Deleted** (default: `DeleteOnTermination=true`) | Deleted if `DeleteOnTermination=true`, otherwise detached | **Disassociated, not released** | Lost | Lost |

Key rule: `DeleteOnTermination` on the root volume defaults to `true`. Additional volumes attached after launch default to `false` — they become orphaned EBS volumes after termination and continue to bill at $0.08–0.10/GB/month. Set `DeleteOnTermination=true` at launch for ephemeral workloads.

### CLI: Launch, Stop, Start, Terminate

```bash
# Get the latest Amazon Linux 2023 AMI for the current region
AMI_ID=$(aws ssm get-parameter \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64 \
  --query Parameter.Value --output text)

# Launch — every required parameter must be explicit
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --count 1 \
  --subnet-id subnet-0abc123 \
  --security-group-ids sg-0abc123 \
  --key-name my-keypair \
  --iam-instance-profile Name=my-instance-profile \
  --metadata-options HttpTokens=required \
  --block-device-mappings '[{
    "DeviceName": "/dev/xvda",
    "Ebs": {"VolumeSize": 20, "VolumeType": "gp3",
            "Encrypted": true, "DeleteOnTermination": true}
  }]' \
  --tag-specifications 'ResourceType=instance,Tags=[
    {Key=Name,Value=app-server},
    {Key=Environment,Value=production}
  ]' \
  --query 'Instances[0].InstanceId' --output text)

# Wait for running state before proceeding
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# Stop (EBS persists, no compute charge, can be restarted)
aws ec2 stop-instances --instance-ids $INSTANCE_ID
aws ec2 wait instance-stopped --instance-ids $INSTANCE_ID

# Start a stopped instance
aws ec2 start-instances --instance-ids $INSTANCE_ID
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# Terminate (destructive — irreversible)
# Always describe first to confirm what will be deleted
aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].{
    State:State.Name,
    Name:Tags[?Key==`Name`].Value|[0],
    Type:InstanceType,
    IP:PublicIpAddress
  }'
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
```

### Key Pair Management

A key pair is an RSA keypair. AWS stores the **public key** and injects it into `~/.ssh/authorized_keys` on first boot via cloud-init. You store the **private key** (`.pem` file) locally. AWS never stores the private key — losing it means losing SSH access permanently.

```bash
# Create a new key pair and save the private key
aws ec2 create-key-pair \
  --key-name my-keypair \
  --query KeyMaterial \
  --output text > ~/.ssh/my-keypair.pem
chmod 400 ~/.ssh/my-keypair.pem    # SSH refuses to use key if permissions are too open

# List existing key pairs in the account
aws ec2 describe-key-pairs \
  --query 'KeyPairs[*].{Name:KeyName,Fingerprint:KeyFingerprint}'

# Import an existing public key (if you generated the keypair locally)
aws ec2 import-key-pair \
  --key-name my-keypair \
  --public-key-material fileb://~/.ssh/id_rsa.pub

# Delete a key pair (does not affect running instances that already used it)
aws ec2 delete-key-pair --key-name my-keypair
```

**If you lose the private key:** Create a new key pair, then use SSM Session Manager (if SSM agent is installed and the instance has an IAM role with `AmazonSSMManagedInstanceCore`) to add the new public key to `~/.ssh/authorized_keys` without SSH.

```bash
# Access instance via SSM without SSH (no key required)
aws ssm start-session --target $INSTANCE_ID
```

### Elastic IP

An Elastic IP (EIP) is a static public IPv4 address that belongs to your AWS account, not to any specific instance.

```bash
# Allocate an EIP
ALLOC_ID=$(aws ec2 allocate-address --domain vpc \
  --query AllocationId --output text)

# Associate with a running instance
aws ec2 associate-address \
  --instance-id $INSTANCE_ID \
  --allocation-id $ALLOC_ID

# EIP persists through stop/start — public IP does not change
# EIP costs $0.005/hour when NOT associated with a running instance
# Always release when done

aws ec2 disassociate-address \
  --association-id $(aws ec2 describe-addresses \
    --allocation-ids $ALLOC_ID \
    --query 'Addresses[0].AssociationId' --output text)
aws ec2 release-address --allocation-id $ALLOC_ID
```

---

## 2. S3 Operations

### S3 is Flat Key-Value Storage

S3 has no real directory hierarchy. An object's "path" (`config/app/db.json`) is its entire **key** — a string. The `/` delimiter is a convention that the AWS console and CLI display as folders. There is no difference between key `config/app/db.json` and key `configXappXdb.json` at the storage layer.

**Implication:** When an application cannot find an object, the first diagnostic step is listing all keys with `--recursive` to see the exact key stored, then comparing it to what the app is constructing.

```bash
# The trailing slash matters for how CLI infers the key
aws s3 cp config.json s3://mybucket/          # key = "config.json"
aws s3 cp config.json s3://mybucket/app/      # key = "app/config.json"
aws s3 cp config.json s3://mybucket/app/cfg   # key = "app/cfg"  ← explicit rename

# Best practice: always specify the full key explicitly
aws s3api put-object \
  --bucket mybucket \
  --key app/config/config.json \
  --body config.json \
  --content-type "application/json"
```

### Core S3 CLI Operations

```bash
BUCKET="my-app-bucket"
REGION="ap-southeast-1"

# Create bucket (us-east-1 does NOT use LocationConstraint — all other regions do)
aws s3api create-bucket \
  --bucket $BUCKET \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION

# Block all public access (required for any non-static-website bucket)
aws s3api put-public-access-block \
  --bucket $BUCKET \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,\
BlockPublicPolicy=true,RestrictPublicBuckets=true

# Upload object with explicit content-type
aws s3 cp config.json s3://$BUCKET/config/config.json \
  --content-type "application/json"

# Upload with server-side encryption (SSE-S3)
aws s3 cp secret.env s3://$BUCKET/secrets/app.env \
  --sse AES256

# Download to local file
aws s3 cp s3://$BUCKET/config/config.json ./config.json

# Stream object directly to stdout (no temp file)
aws s3 cp s3://$BUCKET/config/config.json -

# List all objects recursively (shows exact keys, not simulated folders)
aws s3 ls s3://$BUCKET/ --recursive --human-readable

# Verify object exists and check metadata (no download)
aws s3api head-object \
  --bucket $BUCKET \
  --key config/config.json \
  --query '{Size:ContentLength,Type:ContentType,Modified:LastModified}'

# Delete a single object
aws s3 rm s3://$BUCKET/config/old-config.json

# Sync local directory to S3 (only uploads changed files)
aws s3 sync ./configs/ s3://$BUCKET/configs/ --delete
```

### Bucket Policy vs IAM Policy — When Each Controls Access

Both are JSON policy documents evaluated by AWS IAM. The difference is **where the policy is attached** and **who it grants access to**.

| | IAM Policy | Bucket Policy |
|-|-----------|--------------|
| **Attached to** | IAM user, role, or group | The S3 bucket itself |
| **Controls** | What *this principal* can do across AWS | Who can access *this bucket* from anywhere |
| **Cross-account access** | Requires both IAM policy AND bucket policy | Bucket policy alone can grant cross-account read |
| **Public access** | Cannot make S3 public alone | Can make objects public (if block-public-access is off) |
| **When to use** | Your own EC2/Lambda needing S3 access → use IAM role | Another AWS account, CloudFront, or specific IP ranges needing access → use bucket policy |

```bash
# Example: bucket policy restricting access to a specific IAM role ARN
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws s3api put-bucket-policy \
  --bucket $BUCKET \
  --policy "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Effect\": \"Allow\",
      \"Principal\": {
        \"AWS\": \"arn:aws:iam::${ACCOUNT_ID}:role/app-ec2-role\"
      },
      \"Action\": [\"s3:GetObject\", \"s3:ListBucket\"],
      \"Resource\": [
        \"arn:aws:s3:::${BUCKET}\",
        \"arn:aws:s3:::${BUCKET}/*\"
      ]
    }]
  }"
```

### Versioning

Versioning stores every version of every object in a bucket; overwriting a key does not delete the previous version, and deleted objects become version-marked delete markers rather than permanent removals. Enable it on any bucket storing config, artifacts, or backups.

```bash
aws s3api put-bucket-versioning \
  --bucket $BUCKET \
  --versioning-configuration Status=Enabled

# List all versions of an object (including deleted)
aws s3api list-object-versions \
  --bucket $BUCKET \
  --prefix config/config.json

# Restore a previous version by copying it
aws s3api copy-object \
  --bucket $BUCKET \
  --copy-source "$BUCKET/config/config.json?versionId=abc123" \
  --key config/config.json
```

---

## 3. VPC Networking

### Architecture: What Each Component Does

```
Internet
    │
    ▼
Internet Gateway (IGW)
    │  ← bidirectional: inbound AND outbound
    │  ← one per VPC, attached to VPC not to subnet
    │
    ▼
Public Subnet (10.0.1.0/24)
  Route Table:
    10.0.0.0/16 → local     ← intra-VPC traffic always uses local route
    0.0.0.0/0   → igw-xxx   ← THIS is what makes a subnet "public"
    │
    ├── EC2 with Public IP   ← reachable from internet if SG allows
    └── NAT Gateway          ← must live in public subnet to reach IGW
              │
              │ (outbound only — no inbound from internet)
              ▼
    Private Subnet (10.0.2.0/24)
      Route Table:
        10.0.0.0/16 → local
        0.0.0.0/0   → nat-xxx   ← outbound to internet; no inbound from internet
        │
        ├── App servers (no public IP)
        └── RDS, ElastiCache, internal services
```

### Public Subnet vs Private Subnet — Decision Table

| Characteristic | Public Subnet | Private Subnet |
|---------------|--------------|----------------|
| Default route target | Internet Gateway | NAT Gateway (or none) |
| Can receive inbound from internet | Yes, if instance has public IP + SG allows | Never — no route exists |
| Can initiate outbound to internet | Yes, directly via IGW | Yes, via NAT Gateway (outbound only) |
| Instance needs public IP | Optional | Not assigned (even if requested) |
| Use for | Load balancers, bastion hosts, NAT Gateway itself | App servers, databases, caches, internal services |

### Security Groups — Stateful Firewall

Security groups are stateful — they track connection state. If an outbound connection from EC2 to RDS on port 5432 is allowed, the return packets from RDS to EC2 are automatically permitted without a separate inbound rule. This is the "stateful" property.

**Practical consequence:** You never need to write a rule for return traffic. Only write rules for the *initiating* direction of each connection.

```
EC2 initiates → RDS:5432   → needs: EC2 outbound rule (port 5432) + RDS inbound rule (port 5432)
RDS response → EC2:random  → automatic (stateful) — no rule needed
```

#### Security Group Rules for a Web + DB Architecture

```bash
VPC_ID="vpc-0abc123"

# ── Web Server SG ──────────────────────────────────────────────
WEB_SG=$(aws ec2 create-security-group \
  --group-name web-sg \
  --description "Web: HTTPS inbound, PostgreSQL outbound" \
  --vpc-id $VPC_ID \
  --query GroupId --output text)

# Inbound: HTTPS from internet
aws ec2 authorize-security-group-ingress \
  --group-id $WEB_SG --protocol tcp --port 443 --cidr 0.0.0.0/0

# Inbound: SSH from your IP only (for initial setup — remove after SSM configured)
MY_IP=$(curl -s https://checkip.amazonaws.com)/32
aws ec2 authorize-security-group-ingress \
  --group-id $WEB_SG --protocol tcp --port 22 --cidr $MY_IP

# Remove default "allow all outbound" — replace with least-privilege
aws ec2 revoke-security-group-egress \
  --group-id $WEB_SG --protocol -1 --cidr 0.0.0.0/0

# Outbound: only to DB on port 5432
aws ec2 authorize-security-group-egress \
  --group-id $WEB_SG --protocol tcp --port 5432 --cidr 10.0.2.0/24

# ── Database SG ────────────────────────────────────────────────
DB_SG=$(aws ec2 create-security-group \
  --group-name db-sg \
  --description "DB: PostgreSQL from web-sg only" \
  --vpc-id $VPC_ID \
  --query GroupId --output text)

# Inbound: PostgreSQL from web-sg only (SG reference, not CIDR — more precise)
aws ec2 authorize-security-group-ingress \
  --group-id $DB_SG --protocol tcp --port 5432 \
  --source-group $WEB_SG

# Remove all outbound (DB initiates no external connections)
aws ec2 revoke-security-group-egress \
  --group-id $DB_SG --protocol -1 --cidr 0.0.0.0/0
```

**SG reference vs CIDR:** Using `--source-group $WEB_SG` means only instances with `web-sg` attached can connect — not every IP in the subnet. This survives subnet expansion and IP changes. Prefer SG references for intra-VPC service-to-service rules.

### Internet Gateway vs NAT Gateway — When to Use Each

| Gateway | Direction | Who uses it | Cost |
|---------|-----------|-------------|------|
| **Internet Gateway (IGW)** | Inbound + outbound | Public subnet instances with a public IP | Free (data transfer charges still apply) |
| **NAT Gateway** | Outbound only | Private subnet instances that need to reach internet (package installs, external API calls) | ~$0.045/GB processed + $0.045/hour |

**NAT Gateway placement rule:** One NAT Gateway per AZ, placed in the public subnet of that AZ. Private subnets in each AZ route to their local NAT Gateway. Routing cross-AZ through a single NAT Gateway adds ~$0.01/GB inter-AZ transfer charge to the ~$0.045/GB NAT processing charge.

```bash
# NAT Gateway requires an EIP
EIP_ALLOC=$(aws ec2 allocate-address --domain vpc \
  --query AllocationId --output text)

NAT_GW=$(aws ec2 create-nat-gateway \
  --subnet-id $PUBLIC_SUBNET \
  --allocation-id $EIP_ALLOC \
  --query 'NatGateway.NatGatewayId' --output text)

# NAT Gateway takes ~60 seconds to become available
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW

# Add route in private subnet route table
aws ec2 create-route \
  --route-table-id $PRIVATE_RT \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id $NAT_GW
```

### Check Connectivity Diagnostics

```bash
# Is the instance in a public or private subnet?
aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].{
    PublicIP:PublicIpAddress,
    PrivateIP:PrivateIpAddress,
    SubnetId:SubnetId
  }'

# Does the subnet have a route to IGW?
SUBNET_ID="subnet-0abc123"
RT_ID=$(aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=$SUBNET_ID" \
  --query 'RouteTables[0].RouteTableId' --output text)

aws ec2 describe-route-tables \
  --route-table-ids $RT_ID \
  --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`]'
# GatewayId starts with "igw-"  → public subnet
# NatGatewayId starts with "nat-" → private subnet
# Empty → no internet access at all

# Does the SG allow SSH (port 22)?
SG_ID=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)
aws ec2 describe-security-groups --group-ids $SG_ID \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]'
```

---

## 4. IAM Fundamentals

### User vs Role vs Policy — Three Distinct Concepts

| Concept | What it is | Has credentials? | Assumed by |
|---------|-----------|-----------------|-----------|
| **IAM User** | A persistent identity for a human or service | Yes — long-lived access key + optional password | Nobody assumes it — it IS the identity |
| **IAM Role** | A set of permissions with no permanent credentials | No — STS issues short-lived tokens on assumption | EC2, Lambda, ECS, another AWS account, federated user |
| **IAM Policy** | A JSON document defining Allow/Deny rules | N/A — not an identity | Attached to users, roles, or groups |

**Policy evaluation order:**

```
Explicit Deny  →  always wins, regardless of any Allow
      │
      ▼
Explicit Allow  →  grants the action
      │
      ▼
Implicit Deny  →  default; nothing is allowed unless explicitly granted
```

### Why EC2 Must Use Roles, Never Access Keys

Static access keys (long-lived `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY`) placed on an EC2 instance create these specific risks:

1. **SSRF vulnerability:** A bug in the application that allows server-side request forgery can expose `/proc/environ` or environment variables, leaking the key to an attacker.
2. **Accidental git commit:** An engineer copies the key from the instance and commits it to a repository. GitHub's automated scanners detect and notify, but by then the key may already be extracted.
3. **AMI leak:** If an AMI is created from the running instance and shared or accidentally made public, the key is embedded in the image.
4. **No automatic rotation:** Static keys do not expire. A leaked key remains valid until manually revoked. Finding and revoking it requires knowing which systems used it.

**IAM Role + Instance Profile eliminates all four risks:** credentials are temporary (1–12 hours), automatically rotated by STS, never written to disk, and accessible only from within the instance via the link-local IMDS address.

### Instance Profile — The Mechanism

An Instance Profile is a container object that allows EC2 to use an IAM Role. When you create a role for EC2 via the console, the console automatically creates an Instance Profile with the same name. The CLI requires creating both explicitly.

```bash
# 1. Create role with EC2 trust policy (who can assume this role)
aws iam create-role \
  --role-name app-ec2-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

# 2. Attach permissions to the role (what the role can do)
# Option A: AWS managed policy (broad — use only when scope is acceptable)
aws iam attach-role-policy \
  --role-name app-ec2-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

# Option B: Inline policy scoped to a specific bucket (least privilege)
aws iam put-role-policy \
  --role-name app-ec2-role \
  --policy-name s3-config-read \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::my-config-bucket",
        "arn:aws:s3:::my-config-bucket/config/*"
      ]
    }]
  }'

# 3. Create instance profile (CLI requires this separate step)
aws iam create-instance-profile \
  --instance-profile-name app-instance-profile

# 4. Add role to instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name app-instance-profile \
  --role-name app-ec2-role

# 5. Wait for IAM propagation before using in EC2 launch
sleep 15

# 6. Attach to a running instance (if not done at launch)
aws ec2 associate-iam-instance-profile \
  --instance-id $INSTANCE_ID \
  --iam-instance-profile Name=app-instance-profile
```

### How the SDK Gets Credentials — IMDS Flow

The Instance Metadata Service (IMDS) is available only from within the instance at `http://169.254.169.254` — a link-local IP not routable to the internet.

```bash
# IMDSv2: always require a token (protects against SSRF)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# See which role is attached
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/

# Get the actual temporary credentials
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/app-ec2-role
# Returns: AccessKeyId, SecretAccessKey, Token, Expiration
# SDK caches these and refreshes automatically when Expiration < 5 minutes away
```

**SDK credential provider chain** (checked in order until one succeeds):
1. Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
2. `~/.aws/credentials` file
3. `~/.aws/config` file
4. ECS container credentials (if running in ECS)
5. EC2 Instance Metadata Service ← **this is where Instance Profile credentials come from**

If `AWS_ACCESS_KEY_ID` is set in the environment, it takes precedence over the Instance Profile. Always check `env | grep AWS` on an instance when debugging unexpected credential behavior.

### Principle of Least Privilege

Grant the minimum permissions required to perform the specific action on the specific resource, and nothing more — if a role only needs to read one S3 bucket, its policy should name that bucket ARN explicitly, not `arn:aws:s3:::*`.

### Minimum S3 Read Policy — Correct Resource ARNs

The most common IAM mistake with S3 is applying `s3:ListBucket` to the object ARN (`bucket/*`) or `s3:GetObject` to the bucket ARN (`bucket`). The two actions require different resource ARNs.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListBucketContents",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::my-config-bucket",
      "Condition": {
        "StringLike": {"s3:prefix": ["config/*"]}
      }
    },
    {
      "Sid": "ReadConfigObjects",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-config-bucket/config/*"
    }
  ]
}
```

### Diagnosing Access Denied

```bash
# Step 1: Confirm authentication is working (if this fails, the role isn't attached)
aws sts get-caller-identity
# Arn contains "assumed-role" → credentials from Instance Profile (correct)
# Arn contains "user/"        → credentials from IAM User key (investigate)

# Step 2: Check what policies are attached to the role
ROLE_NAME="app-ec2-role"
aws iam list-attached-role-policies --role-name $ROLE_NAME
aws iam list-role-policies --role-name $ROLE_NAME    # inline policies

# Step 3: Read the inline policy
aws iam get-role-policy \
  --role-name $ROLE_NAME \
  --policy-name s3-config-read \
  --query PolicyDocument | python3 -m json.tool

# Step 4: Simulate the specific action against the specific resource
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws iam simulate-principal-policy \
  --policy-source-arn "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}" \
  --action-names s3:GetObject s3:ListBucket \
  --resource-arns \
    "arn:aws:s3:::my-config-bucket" \
    "arn:aws:s3:::my-config-bucket/config/config.json" \
  --query 'EvaluationResults[*].{Action:EvalActionName,Decision:EvalDecision}'
# implicitDeny → no Allow policy covers this action+resource combination → add policy
# explicitDeny → a Deny statement is blocking it → find and remove the Deny
```

---

## 5. AWS CLI Patterns

### Command Structure

```
aws <service> <action> [--<option> <value>] [--query <jmespath>] [--output <format>]
  │      │       │
  │      │       └── action maps to an AWS API operation (camelCase → kebab-case)
  │      └── AWS service name (lowercase: ec2, s3, iam, sts, ssm, rds...)
  └── aws CLI entry point

Examples:
  aws ec2 describe-instances          → EC2:DescribeInstances
  aws s3api put-object                → S3:PutObject
  aws iam create-role                 → IAM:CreateRole
  aws sts get-caller-identity         → STS:GetCallerIdentity
```

### Configure CLI Profiles

```bash
# Configure default profile (prompts for key, secret, region, format)
aws configure

# Configure a named profile for a specific account/role
aws configure --profile production
# Creates entries in ~/.aws/credentials and ~/.aws/config

# Use a named profile for a single command
aws ec2 describe-instances --profile production

# Use a named profile for the entire shell session
export AWS_PROFILE=production

# Configure only the region for the current shell
export AWS_DEFAULT_REGION=ap-southeast-1

# View current configuration
aws configure list
aws configure list --profile production

# Switch roles using a profile (for cross-account or role assumption)
# In ~/.aws/config:
# [profile dev-admin]
# role_arn = arn:aws:iam::123456789012:role/AdminRole
# source_profile = default
# region = ap-southeast-1
```

### `--query` — JMESPath Filtering

`--query` evaluates a JMESPath expression against the raw JSON response before display. Use it to extract only the fields you need.

```bash
# Get a single scalar value
aws ec2 describe-instances \
  --instance-ids i-0abc123 \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text

# Build an object from multiple fields
aws ec2 describe-instances \
  --instance-ids i-0abc123 \
  --query 'Reservations[0].Instances[0].{
    ID:InstanceId,
    Type:InstanceType,
    IP:PublicIpAddress,
    State:State.Name
  }'

# Filter a list by a field value (instances in running state)
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[?State.Name==`running`].[InstanceId,InstanceType]'

# Extract a tag value from the tag array
aws ec2 describe-instances \
  --instance-ids i-0abc123 \
  --query 'Reservations[0].Instances[0].Tags[?Key==`Name`].Value | [0]' \
  --output text

# Flatten nested list with [*] and pipe through sort_by
aws ec2 describe-instances \
  --query 'sort_by(Reservations[*].Instances[*].[InstanceId,LaunchTime][], &[1])'
```

### `--output` Formats

```bash
--output json     # default — full JSON response, good for piping to jq
--output text     # tab-separated, good for shell variable assignment
--output table    # human-readable aligned table, good for interactive review
--output yaml     # YAML format (AWS CLI v2 only)

# Combine --output text with --query for direct variable assignment:
INSTANCE_ID=$(aws ec2 run-instances ... --query 'Instances[0].InstanceId' --output text)
VPC_ID=$(aws ec2 create-vpc ... --query 'Vpc.VpcId' --output text)
```

### The 10 Most Common Commands a DevOps Engineer Runs Daily

```bash
# 1. Verify current identity and account (always run first when debugging access)
aws sts get-caller-identity

# 2. List running EC2 instances with name, type, state, IP
aws ec2 describe-instances \
  --filters Name=instance-state-name,Values=running \
  --query 'Reservations[*].Instances[*].{
    ID:InstanceId,
    Name:Tags[?Key==`Name`].Value|[0],
    Type:InstanceType,
    IP:PublicIpAddress,
    State:State.Name
  }' \
  --output table

# 3. SSH into an instance (confirm key permission before running)
ssh -i ~/.ssh/keypair.pem ec2-user@<PUBLIC_IP>

# 4. Open a session without SSH (requires SSM agent + IAM role)
aws ssm start-session --target i-0abc123

# 5. Check what a role can do (simulate a specific action)
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/ROLE \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::bucket/key \
  --query 'EvaluationResults[*].{Action:EvalActionName,Decision:EvalDecision}'

# 6. List all objects in an S3 bucket (see exact keys)
aws s3 ls s3://bucket-name/ --recursive --human-readable

# 7. Read a file from S3 directly to stdout
aws s3 cp s3://bucket/config/app.json -

# 8. Check security group rules for an instance
aws ec2 describe-security-groups \
  --group-ids $(aws ec2 describe-instances \
    --instance-ids i-0abc123 \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
    --output text) \
  --query 'SecurityGroups[0].{In:IpPermissions,Out:IpPermissionsEgress}'

# 9. Get the latest Amazon Linux 2023 AMI ID for the current region
aws ssm get-parameter \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64 \
  --query Parameter.Value --output text

# 10. Find orphaned resources that are costing money
# Unattached EBS volumes
aws ec2 describe-volumes \
  --filters Name=status,Values=available \
  --query 'Volumes[*].{ID:VolumeId,Size:Size,Created:CreateTime}' \
  --output table

# Unassociated Elastic IPs ($0.005/hr each)
aws ec2 describe-addresses \
  --query 'Addresses[?AssociationId==null].{IP:PublicIp,AllocID:AllocationId}' \
  --output table
```

---

## Common Gotchas

- **`aws s3 cp` with trailing slash does not rename:** `aws s3 cp app.json s3://bucket/config/` uploads the object as `config/app.json`, not `config/`. Always specify the full key when the destination filename must differ from the source.
- **IAM takes 10–15 seconds to propagate:** After `add-role-to-instance-profile`, launching an EC2 instance immediately may result in the instance not finding the role via IMDS. Add `sleep 15` in provisioning scripts.
- **`us-east-1` bucket creation does not use `LocationConstraint`:** `aws s3api create-bucket --bucket x --region us-east-1` works without `--create-bucket-configuration`. Every other region requires `--create-bucket-configuration LocationConstraint=$REGION` or the call fails with a `400 IllegalLocationConstraintException`.
- **`s3:ListBucket` and `s3:GetObject` need different resource ARNs:** `ListBucket` acts on the bucket ARN (`arn:aws:s3:::bucket`); `GetObject` acts on the object ARN (`arn:aws:s3:::bucket/*`). Applying either to the wrong resource silently fails — the policy is valid but the action is still denied.
- **Default outbound rule allows all traffic:** A newly created security group has an implicit `allow all outbound` rule. For least-privilege setups, revoke it with `revoke-security-group-egress --protocol -1 --cidr 0.0.0.0/0` and add explicit egress rules.
- **Security Group SG-reference vs CIDR:** SG reference (`--source-group sg-xxx`) allows only instances with that SG attached, regardless of subnet IP range. CIDR (`--cidr 10.0.1.0/24`) allows any IP in that range. Prefer SG references for intra-VPC service communication.
- **Instance store is lost on stop:** Instance types with NVMe instance store (c5d, m5d, i3, etc.) lose all instance store data when stopped. Use EBS for any data that must survive a stop event.
- **IMDSv1 is a security risk:** IMDSv1 allows metadata retrieval without a token, making it exploitable via SSRF. Always launch with `--metadata-options HttpTokens=required` to enforce IMDSv2.
- **EIP costs money when not associated:** An Elastic IP that is allocated but not attached to a running instance costs $0.005/hour (~$3.60/month). Release EIPs immediately when not in use.
- **Terminated instances are not immediately gone from describe-instances:** They remain visible with state `terminated` for up to an hour. Filter by state when scripting to avoid acting on terminated instances.

---

## Architecture Decision Rules (agent use)

1. **Never generate EC2 launch configs with static access keys.** Always use IAM roles and Instance Profiles. If the user's design includes `AWS_ACCESS_KEY_ID` in user-data or environment variables, flag it as a security violation.
2. **Default to IMDSv2 (`HttpTokens=required`) on all new instances.** IMDSv1 is a known SSRF vector. No exceptions.
3. **Application servers go in private subnets.** Only load balancers and bastion hosts belong in public subnets. If someone asks to put a DB in a public subnet, refuse and explain the risk.
4. **Use SG references, not CIDRs, for intra-VPC service-to-service rules.** CIDRs couple rules to IP addresses that change; SG references are stable and more precise.
5. **Always scope IAM policies to specific resource ARNs.** Never write `"Resource": "*"` on S3 actions unless the action is `s3:ListAllMyBuckets` which requires it. Name the bucket ARN explicitly.
6. **When debugging `Access Denied`:** run `aws sts get-caller-identity` first to confirm authentication. Then `simulate-principal-policy` to confirm which specific action + resource combination is blocked. Never guess — simulate.
7. **One NAT Gateway per AZ for production.** A single NAT Gateway creates both a single point of failure and inter-AZ data transfer charges for subnets in other AZs.
8. **`gp3` over `gp2` for all new EBS volumes.** gp3 is 20% cheaper than gp2 at the same size and delivers 3,000 IOPS baseline without the burst credit model.

---

## Links to Related Memory Files

- See also: `memory/cloud-concepts.md` — IaaS/PaaS/SaaS comparison, AZ HA design, cost mechanics
- See also: `memory/networking-basics.md` — TCP/IP, subnetting, routing, DNS fundamentals
- See also: `memory/linux-basics.md` — filesystem layout, systemd, process debugging on EC2 instances
- See also: `memory/docker.md` — container image building, registry push to ECR
- See also: `memory/kubernetes-core.md` — deploying containerized apps on EC2-backed node groups
