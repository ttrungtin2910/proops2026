---
name: iac-basics
description: IaC fundamentals — Terraform vs Ansible split, core commands, state rules, decision table, Day 19 errors
metadata:
  type: project
---

# IaC Basics

## 1. The Two-Tool Rule

- **Terraform** manages WHAT infrastructure exists: EC2, VPC, SG, EKS, S3, IAM roles.
- **Ansible** manages WHAT is installed and running on it: packages, files, services, users.
- **Bash** is the glue between the two — copy outputs, trigger playbooks, wrap the workflow.

---

## 2. Terraform Core Commands

```bash
terraform init          # download provider plugins → .terraform/, create .terraform.lock.hcl
terraform plan          # diff: main.tf vs tfstate + AWS API. ALWAYS run before apply.
terraform apply         # execute plan. Type "yes" only after reading the summary line.
terraform destroy       # delete all managed resources. Verify with AWS CLI after.
terraform state list    # show all resources currently in the state file
terraform output        # print output values (e.g. instance_public_ip)
terraform validate      # syntax check — no AWS credentials needed
terraform state show aws_instance.app   # full attributes of one resource
terraform import aws_instance.app i-0abc  # re-link existing AWS resource to state
```

**Variable input priority (high → low):**
```
CLI -var flag  >  *.auto.tfvars  >  terraform.tfvars  >  TF_VAR_*  >  default in variable {}
```

---

## 3. State File Rules (non-negotiable)

- **Never commit** `terraform.tfstate` to git — contains resource IDs, may contain secrets
- **Never edit manually** — use `terraform state` commands
- **In production:** S3 backend + DynamoDB lock (prevent concurrent apply corruption)
- **After losing state:** `terraform import` each resource back — painful, prevention is better
- `serial` field increments every write; empty `resources: []` after destroy is normal
- `lineage` UUID never changes — identifies the state lineage across all operations

```hcl
# S3 backend pattern
terraform {
  backend "s3" {
    bucket         = "my-tfstate-bucket"
    key            = "proops2026/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

---

## 4. Gitignore for Terraform

```gitignore
.terraform/              # provider binaries (~100MB)
terraform.tfstate        # state file
terraform.tfstate.backup # auto-backup before each apply
*.tfvars                 # actual values (use *.tfvars.example for templates)
# .terraform.lock.hcl   # optional — many teams DO commit this to pin provider versions
```

---

## 5. Ansible Core Concepts

```
inventory.ini   — list of hosts + connection vars (ansible_host, ansible_user, ansible_ssh_private_key_file)
playbook.yml    — ordered list of plays → tasks → handlers
module          — built-in verb: dnf, apt, copy, service, template, uri, file
handler         — task that only runs when notified (e.g. restart nginx only if config changed)
become: true    — sudo on remote host
```

**Key state values:**
```yaml
state: present   # install / ensure exists (idempotent)
state: absent    # remove
state: started   # service is running now
state: enabled   # service starts on reboot
```

**Commands:**
```bash
ansible webservers -i inventory.ini -m ping            # test SSH before running playbooks
ansible-playbook playbook.yml -i inventory.ini         # run playbook
ansible-playbook playbook.yml -i inventory.ini -vvv    # verbose (debug SSH issues)
```

**Read the PLAY RECAP:**
```
ok=N      — tasks that ran and found no change needed
changed=N — tasks that actually modified something
failed=N  — must be 0
```
Second run should show `changed=0` — that proves idempotency.

**Amazon Linux 2023:** use `ansible.builtin.dnf`, not `ansible.builtin.yum`

**WSL2 ansible.cfg ignored (world-writable dir):**
```bash
export ANSIBLE_CONFIG=/mnt/d/14-AIOps_TinTT33/proops2026/iac/ansible/ansible.cfg
```

---

## 6. Decision Table

| Task | Tool |
|---|---|
| Create EC2 instance | Terraform |
| Create VPC, SG, EKS cluster | Terraform |
| Install nginx / packages on EC2 | Ansible |
| Deploy app with git pull | Bash or Ansible |
| Configure K8s app | kubectl (or Ansible) |
| One-off AWS query | AWS CLI / Bash |
| Test SSH connectivity | `ansible -m ping` |
| Verify infra after apply | `terraform output` + AWS CLI |

---

## 7. Day 19 Errors + Fixes

**Error 1: `ansible ping` → Connection timed out**
```
msg: "Failed to connect to host via ssh: Connection timed out"
```
Fix: Security Group had no inbound rule for port 22.
```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-XXXX --protocol tcp --port 22 --cidr 0.0.0.0/0 --region ap-northeast-1
```
Also needed port 80 for curl test — add same command with `--port 80`.

**Error 2: `Permission denied` writing .pem to `~/.ssh/`**
```
-bash: /home/trungtin/.ssh/proops2026-day19.pem: Permission denied
```
Fix: `~/.ssh` didn't exist or was owned by root.
```bash
sudo mkdir -p ~/.ssh && sudo chown trungtin:trungtin ~/.ssh && chmod 700 ~/.ssh
```
Alternative: write to `/tmp/` first, then `sudo mv` to `~/.ssh/`.

**Error 3: `ec2:CreateKeyPair` denied by tag enforcement policy**
```
not authorized to perform: ec2:CreateKeyPair ... explicit deny in trainne-tag-enforcement
```
Fix: add `--tag-specifications` with required tags, OR create key via AWS Console (UI bypass),
OR use an existing key pair already in the account.

**Error 4: `aws` command not found in WSL2**
```
Command 'aws' not found
```
Fix: AWS CLI not installed in WSL2. Use PowerShell for AWS commands, WSL2 for Ansible.
Pattern: PowerShell handles `terraform` + `aws` CLI, WSL2 handles `ansible`.

**Error 5: ansible.cfg ignored — world writable directory warning**
```
[WARNING]: Ansible is being run in a world writable directory, ignoring it as an ansible.cfg source.
```
Fix: `/mnt/d/` is 777 in WSL2 (Windows NTFS mount). Ansible refuses config from 777 dirs.
```bash
export ANSIBLE_CONFIG=/mnt/d/14-AIOps_TinTT33/proops2026/iac/ansible/ansible.cfg
```
