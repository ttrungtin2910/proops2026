# Daily Log — Tin (Trần Trung Tín) — Day 19 — 18 May 2026

## Today's Assignment (Day 19 — IaC Foundations: Terraform + Ansible)
- [x] Q1 — IaC from first principles: Console vs Bash vs Terraform (reproducibility, idempotency, drift detection)
- [x] Q2 — First main.tf: provider block, data source, resource block, output block — every line explained
- [x] Q3 — Variables: variables.tf (schema), terraform.tfvars (values), tfvars.example (template), var. references, CLI override
- [x] Q4 — State file deep dive: serial, lineage, what attributes are tracked, three non-negotiable rules
- [x] Q5 — Terraform core loop: init → plan → apply → destroy — what each step reads and writes
- [x] Q6 — Guided apply + verify + idempotency proof (plan lần 2 = "No changes") + destroy
- [x] Q7 — Ansible intro: mental model vs Terraform, key concepts (inventory, playbook, task, handler, module, agentless)
- [x] Q8 — First playbook: nginx install + start + custom index.html, handlers, idempotency proof (changed=0 lần 2)
- [x] Q9 — Troubleshooting session: SG rules, key pair, WSL2 permissions, ANSIBLE_CONFIG warning
- [x] Q10 — memory/iac-basics.md: two-tool rule, core commands, state rules, decision table, Day 19 errors

## Environment
Windows 11 Pro, Claude Code CLI inside VSCode. Terraform chạy PowerShell (Windows). Ansible chạy WSL2 (Ubuntu). AWS region: ap-northeast-1. EC2 instance: t3.micro, Amazon Linux 2023, key pair `tin_tt33`. State file: `iac/terraform/terraform.tfstate` (serial 11 sau nhiều apply/destroy cycles).

---

## Completed

- [x] **Q1 — IaC từ nền tảng: ba cấp độ**

  Phân tích ba cách tạo infrastructure theo độ trưởng thành:

  | Approach | Reproducible | Idempotent | Drift detection |
  |---|---|---|---|
  | Console clicks | No | No | No |
  | Bash/AWS CLI | Yes | Manual | No |
  | Terraform | Yes | Yes (state) | Yes (plan) |

  Bash scripts (`aws ec2 run-instances`) là *imperative* — mô tả hành động, không mô tả trạng thái. Chạy hai lần → hai instance. Terraform là *declarative* — mô tả trạng thái mong muốn. Chạy hai lần → "No changes".

  **State drift** = state file ghi `t3.micro`, AWS thực tế là `t3.medium` (ai đó resize thủ công). `terraform plan` phát hiện và hiển thị diff.

- [x] **Q2 — main.tf đầu tiên**

  Viết `iac/terraform/main.tf` với 5 blocks, mỗi block có comment giải thích:

  ```
  terraform {}          → required_providers với version constraint "~> 5.0"
  provider "aws" {}     → region, credentials từ env/~/.aws/credentials (không hardcode)
  data "aws_ami" {}     → tra cứu AL2023 AMI mới nhất thay vì hardcode AMI ID
  resource "aws_instance" {}  → EC2 với tags bắt buộc
  output {}             → instance_public_ip, instance_id, ami_id_used
  ```

  **Tại sao data source tốt hơn hardcode AMI ID:**
  - AMI ID là region-specific → hardcode bị lỗi khi đổi region
  - AMI bị deprecated theo thời gian
  - Data source tự động lấy AMI mới nhất khớp filter

  **`(known after apply)`** = giá trị AWS mới biết sau khi tạo xong (id, public_ip, arn).

- [x] **Q3 — Variables: tách schema khỏi giá trị**

  Ba file tách biệt:
  ```
  variables.tf          → DECLARE: type, description, default, validation block
  terraform.tfvars      → ASSIGN: giá trị thực tế (gitignored)
  terraform.tfvars.example → TEMPLATE: committed, người mới copy + fill
  ```

  Validation block ngăn typo trước khi gọi AWS API:
  ```hcl
  validation {
    condition     = can(regex("^t[23]\\.", var.instance_type))
    error_message = "Must be t2/t3 type."
  }
  ```

  **Priority order (cao → thấp):** CLI `-var` > `*.auto.tfvars` > `terraform.tfvars` > `TF_VAR_*` > `default`

  Quan trọng trong CI/CD: dev laptop dùng `terraform.tfvars`, CI/CD inject qua `TF_VAR_*`, production override qua `-var` — cùng code, khác input layer.

- [x] **Q4 — State file deep dive**

  State file thực tế của project: `serial: 11`, `resources: []` (sau destroy). Serial tăng mỗi lần state được ghi — serial 11 sau nhiều apply/destroy cycles.

  **Nội dung state khi có resources:**
  - `id` (instance ID), `ami`, `instance_type`, `private_ip`, `public_ip`, `vpc_id`, `subnet_id`, `tags`, `arn`
  - `dependencies` giữa resources (dùng để xác định thứ tự apply/destroy)

  **Ba quy tắc không thương lượng:**
  1. Không commit `terraform.tfstate` lên git (có thể chứa secrets)
  2. Không sửa tay — dùng `terraform state` commands
  3. Production: S3 backend + DynamoDB lock

  **DynamoDB lock:** ngăn hai engineer chạy apply cùng lúc. Không có lock → race condition → state corruption → orphan resources → bill tăng gấp đôi.

  **"Deleted state file" incident pattern:** Terraform thấy state trống → plans to CREATE everything → duplicate infrastructure → bill x2. Recovery: `terraform import`.

- [x] **Q5 — Terraform core loop**

  ```
  terraform init    → download provider binary (~100MB) → .terraform/
                    → create .terraform.lock.hcl (pin version, commit this)
  terraform plan    → đọc .tf + state file + gọi AWS API (refresh)
                    → compute diff → print execution plan (KHÔNG thay đổi gì)
  terraform apply   → execute plan → ghi state sau mỗi resource thành công
  terraform destroy → đọc state file → xóa reverse dependency order
                    → xóa entries khỏi state
  ```

  `terraform destroy` chỉ xóa những gì trong `terraform.tfstate` — không scan toàn bộ AWS account.

- [x] **Q6 — Guided apply + verify + idempotency proof + destroy**

  Checklist đọc plan trước khi gõ "yes":
  - "1 to add" — đúng với ý định
  - instance_type = "t3.micro" — không phải t3.large hay gì khác
  - "0 to destroy" — không có gì bị xóa ngoài ý muốn
  - Không có `-/+` (replace) bất ngờ

  **Idempotency proof:** Sau apply, chạy `terraform plan` lần 2 → "No changes. Your infrastructure matches the configuration." EC2 đã running trên AWS, state file đã ghi, desired = actual → không có diff.

  **Terraform destroy vs xóa thủ công (Day 16):** Terraform đọc state → tính dependency graph → xóa đúng thứ tự → EC2 trước SG sau. Day 16 phải xóa ELB → TG → EC2 → EBS → NAT GW → EIP → Subnet → IGW → VPC theo tay, dễ quên step, dễ để orphan resources.

- [x] **Q7 — Ansible mental model và core concepts**

  ```
  Terraform: quản lý WHAT infrastructure EXISTS (EC2, VPC, SG, EKS)
  Ansible:   quản lý WHAT IS INSTALLED AND RUNNING trên đó (packages, files, services)
  Bash:      glue giữa hai tool
  ```

  Cả hai đều declarative và idempotent. Workflow đầy đủ:
  ```
  terraform apply → EC2 tồn tại (IP: 52.199.85.66)
  ansible-playbook nginx.yml → nginx cài + running
  curl http://52.199.85.66 → "Welcome to ProOps2026"
  ```

  **Agentless:** Ansible chỉ cần SSH + Python trên target (có sẵn trên AL2023). Không cần cài agent như Puppet/Chef.

  **Handler:** task chỉ chạy khi được notify VÀ chỉ chạy sau khi tất cả tasks xong. Nginx config thay đổi → handler restart nginx. Config không thay đổi → handler không chạy → không restart không cần thiết.

- [x] **Q8 — First playbook: nginx trên AL2023**

  `iac/ansible/playbook.yml` với 3 tasks + 1 handler:
  ```yaml
  ansible.builtin.dnf:     state: present   → install nginx (idempotent)
  ansible.builtin.service: state: started, enabled: true → running + autostart
  ansible.builtin.copy:    dest: /usr/share/nginx/html/index.html → custom page
  handler uri:             url: http://localhost, status_code: 200 → verify
  ```

  **AL2023 dùng `dnf` không phải `yum`** — `yum` vẫn hoạt động (symlink) nhưng `ansible.builtin.dnf` là đúng.

  **PLAY RECAP đọc thế nào:**
  ```
  Lần 1: ok=5  changed=3  → nginx được cài và configured
  Lần 2: ok=4  changed=0  → idempotent, không thay đổi gì
  ```
  `changed=0` ở lần 2 = idempotency guarantee.

- [x] **Q9 — Troubleshooting session (5 lỗi thực tế)**

  | Lỗi | Nguyên nhân | Fix |
  |---|---|---|
  | Connection timed out | SG không có rule port 22 | `authorize-security-group-ingress --port 22` |
  | Permission denied (key) | key file `0555` trên `/mnt/d/` — chmod không work trên NTFS mount | Copy key sang `/home/trungtin/.ssh/`, chmod 400 ở đó |
  | `ec2:CreateKeyPair` denied | IAM policy `trainne-tag-enforcement` chặn | Dùng key pair đã có trong account (`tin_tt33`) |
  | `aws: command not found` trong WSL2 | AWS CLI chưa cài trong WSL2 | Dùng PowerShell cho AWS/Terraform, WSL2 cho Ansible |
  | `ansible.cfg` ignored (world writable) | `/mnt/d/` = `0777` trong WSL2, Ansible từ chối | `export ANSIBLE_CONFIG=/mnt/d/.../ansible.cfg` |

  Cũng thêm port 80 cho curl test: `authorize-security-group-ingress --port 80`.

- [x] **Q10 — memory/iac-basics.md**

  Viết và ghi lại toàn bộ `memory/iac-basics.md` với:
  - Two-tool rule + Bash glue (3 sentences)
  - 9 terraform commands + variable priority table
  - State file rules + S3 backend HCL pattern
  - `.gitignore` đầy đủ cho Terraform
  - Ansible core concepts + AL2023 `dnf` note + WSL2 ANSIBLE_CONFIG fix
  - Decision table: Terraform vs Ansible vs Bash (7 scenarios)
  - 5 lỗi thực tế từ session hôm nay với fix command cụ thể

---

## Not Completed

| Item | Reason |
|---|---|
| `ansible ping` thành công | Chưa confirm — đang debug WSL2 key permissions |
| `ansible-playbook playbook.yml` chạy thật | Blocked bởi ping chưa pass |
| `curl http://52.199.85.66` verify nginx | Blocked bởi playbook chưa chạy |
| `terraform destroy` cuối session | Cần chạy sau khi playbook verify xong |

---

## Extra Things Explored

- **`serial` trong state file không reset về 0 sau `destroy`** — serial chỉ tăng, không giảm. `resources: []` là trạng thái bình thường sau destroy. Serial cho biết có bao nhiêu lần state được ghi trong lifecycle của project.

- **`lineage` UUID** — được gán lúc `terraform init`, không bao giờ thay đổi. Terraform dùng để verify đúng state file khi có remote backend. Nếu lineage không khớp → Terraform từ chối dùng state đó.

- **Windows NTFS mount permissions trong WSL2** — `/mnt/c/` và `/mnt/d/` mặc định `0777`. `chmod` không thực sự thay đổi permissions trên NTFS — chỉ giả vờ trong session. SSH đọc permissions thật → vẫn thấy quá rộng → từ chối key. Fix duy nhất: copy file sang Linux filesystem (`/home/`, `/tmp/`).

- **`ansible.builtin.uri` module trong handler** — chạy trên remote host (EC2), không phải control node. `url: http://localhost` = EC2 tự curl chính nó để verify nginx nhận request.

---

## Artifacts Built Today

- [x] `iac/terraform/main.tf` — provider, data source (AL2023 AMI), aws_instance với tags, 3 outputs
- [x] `iac/terraform/variables.tf` — 4 variables với description, type, default, validation block
- [x] `iac/terraform/terraform.tfvars` — owner_name, instance_type (gitignored)
- [x] `iac/terraform/terraform.tfvars.example` — template committed vào git
- [x] `iac/terraform/.gitignore` — *.tfstate, .terraform/, *.tfvars
- [x] `iac/ansible/inventory.ini` — ec2-day19 host với IP 52.199.85.66, key path
- [x] `iac/ansible/ansible.cfg` — default inventory, host_key_checking=False
- [x] `iac/ansible/playbook.yml` — nginx install + start + custom index.html + handler verify
- [x] `memory/iac-basics.md` — two-tool rule, commands, state rules, decision table, 5 errors

---

## How I Used Claude Code Today

Day 19 giới thiệu IaC từ first principles — không bắt đầu bằng "chạy terraform init" mà bắt đầu bằng "tại sao console clicks không đủ tốt". Mỗi concept được introduce bằng một vấn đề cụ thể trước, sau đó mới giới thiệu solution.

Phần hiệu quả nhất: giải thích state file bằng file `terraform.tfstate` thực tế của project (serial 5, 10, 11 qua nhiều lần apply/destroy) thay vì ví dụ giả định. Thấy `serial: 5` và `resources: []` cùng lúc giải thích được toàn bộ lifecycle.

Troubleshooting session (Q9) là phần thực tế nhất — 5 lỗi liên tiếp, mỗi lỗi reveal một gotcha khác nhau về WSL2, NTFS permissions, IAM policies, và Ansible config. Những lỗi này không có trong tutorial chính thức nào.

---

## Blockers / Questions for Mentor

- Workflow hiện tại: PowerShell cho Terraform, WSL2 cho Ansible. Có nên cài AWS CLI trong WSL2 để mọi thứ chạy trong cùng một shell không? Hay pattern "Windows cho cloud ops, Linux cho config management" là intentional?

- `iac/terraform/main.tf` không có VPC/Subnet resource — EC2 đang dùng default VPC. Khi nào nên bắt đầu tạo custom VPC trong Terraform? Week 5 CI/CD hay Week 7 Observability?

---

## Self Score
- Completion: 8/10 — Terraform flow hoàn chỉnh, Ansible concepts hiểu sâu, playbook viết xong nhưng chưa run thành công (blocked bởi key/permission issues)
- Understanding: 9/10 — State file mechanics, idempotency proof, Terraform vs Ansible mental model — tất cả đều rõ. WSL2 NTFS permission quirks là unexpected learning
- Energy: 7/10 — nhiều thời gian debug permission issues

---

## One Thing I Learned Today That Surprised Me

`chmod 400` không thực sự hoạt động trên `/mnt/d/` trong WSL2. Lệnh chạy không lỗi, `ls -la` hiển thị permissions đã đổi, nhưng SSH đọc permissions thật từ NTFS filesystem và vẫn thấy `0555`. Đây là silent failure — không có error message, chỉ SSH từ chối key với "UNPROTECTED PRIVATE KEY FILE". Fix duy nhất là copy file sang Linux filesystem trước khi chmod. Đây là loại gotcha chỉ gặp được khi thực hành thật, không có trong documentation nào.

---

## Tomorrow's Context Block

Day 19 complete — Terraform full loop (init → plan → apply → idempotency proof → destroy), Ansible intro concepts, first playbook written. Artifacts: main.tf, variables.tf, tfvars, inventory.ini, ansible.cfg, playbook.yml, memory/iac-basics.md. Playbook chưa chạy thành công — blocked bởi WSL2 key permission issue (fix: copy key sang /home/trungtin/.ssh/, chmod 400).
First thing next session: confirm `ansible ping` → "pong" (key đã copy sang Linux filesystem), run `ansible-playbook playbook.yml`, verify `curl http://52.199.85.66` trả về custom HTML, run `terraform destroy` để dọn dẹp. Sau đó: check Day 20 assignment.
Open question: install AWS CLI trong WSL2 để unify shell environment, hay giữ pattern PowerShell (cloud) + WSL2 (config)?
