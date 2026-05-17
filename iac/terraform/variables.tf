# =============================================================================
# variables.tf — KHAI BÁO biến, không gán giá trị
# =============================================================================
# File này chỉ định nghĩa SCHEMA của biến: tên, kiểu, mô tả, default.
# Giá trị thực tế đến từ: terraform.tfvars, CLI -var, hoặc env TF_VAR_*
# Rule: một variable block = một biến. Không gộp chung.

variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "ap-northeast-1"
  # Có default → optional khi gọi terraform plan/apply
}

variable "instance_type" {
  description = "EC2 instance type (e.g. t3.micro, t3.small)"
  type        = string
  default     = "t3.micro"
  # Validate để tránh typo hoặc invalid type
  validation {
    condition     = can(regex("^t[23]\\.(nano|micro|small|medium|large)$", var.instance_type))
    error_message = "instance_type must be a valid t2/t3 type (e.g. t3.micro, t3.small)."
  }
}

variable "owner_name" {
  description = "Trainee ID used in resource tags (e.g. tin_tt)"
  type        = string
  # Không có default → REQUIRED — terraform plan sẽ hỏi nếu không được cung cấp
}

variable "project_name" {
  description = "Project name used in resource tags and naming"
  type        = string
  default     = "proops2026"
}
