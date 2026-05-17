# =============================================================================
# BLOCK 1: terraform {} — khai báo yêu cầu về Terraform engine và providers
# =============================================================================
# Block này không tạo resource nào — nó nói với Terraform:
#   "Để chạy code này, bạn cần những plugins nào"
# `terraform init` đọc block này để biết cần download gì.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws" # registry.terraform.io/hashicorp/aws
      version = "~> 5.0"        # chấp nhận 5.x bất kỳ, KHÔNG chấp nhận 6.0
    }
  }
}

# =============================================================================
# BLOCK 2: provider "aws" {} — cấu hình kết nối tới AWS
# =============================================================================
# Provider là "driver" giữa Terraform và AWS API.
# Terraform không biết cách gọi AWS trực tiếp — provider làm việc đó.
# Credentials KHÔNG được hardcode ở đây.
# Terraform tự động đọc từ: AWS_ACCESS_KEY_ID env var, ~/.aws/credentials, hoặc IAM role.
provider "aws" {
  region = var.aws_region   # đọc từ variables.tf → terraform.tfvars → CLI
}

# =============================================================================
# BLOCK 3: data "aws_ami" — tra cứu AMI ID thay vì hardcode
# =============================================================================
# Data source = READ ONLY — Terraform hỏi AWS "AMI mới nhất của Amazon Linux 2023 là gì?"
# Không tạo resource, không thay đổi gì trên AWS.
# Kết quả được dùng bên dưới qua: data.aws_ami.amazon_linux.id
data "aws_ami" "amazon_linux" {
  most_recent = true        # nếu nhiều AMI match, lấy cái mới nhất

  owners = ["amazon"]       # chỉ tin AMI do Amazon publish (không phải community AMI lạ)

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"] # glob pattern: al2023-ami-2023.x.x-x86_64
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]        # Hardware Virtual Machine — loại duy nhất dùng cho EC2 hiện đại
  }
}

# =============================================================================
# BLOCK 4: resource "aws_instance" — khai báo EC2 instance CẦN TỒN TẠI
# =============================================================================
# Cú pháp: resource "TYPE" "LOCAL_NAME"
#   TYPE      = loại resource AWS (aws_instance, aws_s3_bucket, aws_vpc...)
#   LOCAL_NAME = tên bạn đặt để tham chiếu trong Terraform code (không phải tên trên AWS)
#
# Để tham chiếu resource này từ chỗ khác: aws_instance.app.ATTRIBUTE
resource "aws_instance" "app" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type             # t3.micro từ tfvars, override được qua CLI
  key_name      = "tin_tt33"          # tên Key Pair trên AWS (không phải path file)

  tags = {
    Name    = "${var.project_name}-day19"        # "proops2026-day19" — string interpolation
    Owner   = var.owner_name                     # tin_tt từ tfvars
    Email   = "ttrungtin.work@gmail.com"
    Project = var.project_name
    Day     = "19"
  }
}

# =============================================================================
# BLOCK 5: output — in thông tin ra sau khi apply xong
# =============================================================================
# Output không tạo gì trên AWS — chỉ hiển thị giá trị để bạn biết.
# Cú pháp tham chiếu: RESOURCE_TYPE.LOCAL_NAME.ATTRIBUTE
# Danh sách attributes: xem docs tại registry.terraform.io/providers/hashicorp/aws
output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.app.public_ip
}

output "instance_id" {
  description = "EC2 instance ID (dùng để SSH hoặc debug)"
  value       = aws_instance.app.id
}

output "ami_id_used" {
  description = "AMI ID thực tế được dùng (để verify data source hoạt động đúng)"
  value       = data.aws_ami.amazon_linux.id
}
