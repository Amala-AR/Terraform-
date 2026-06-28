# ============================================================
# variables.tf — declared ONCE, values come from .tfvars files
# ============================================================

variable "project" {
  description = "Project name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}

variable "key_pair_name" {
  description = "EC2 Key Pair name. Empty = use SSM Session Manager."
  type        = string
  default     = ""
}

variable "ssh_cidr" {
  description = "CIDR allowed for SSH"
  type        = string
  default     = "0.0.0.0/0"
}

variable "app_port" {
  description = "Application port to open (0 = skip)"
  type        = number
  default     = 8080
}

variable "associate_public_ip" {
  description = "Assign public IP to instance"
  type        = bool
  default     = true
}

variable "create_eip" {
  description = "Create Elastic IP (recommended for prod only)"
  type        = bool
  default     = false
}

variable "sns_alert_arn" {
  description = "SNS topic ARN for prod CloudWatch alarms. Empty string for dev/staging."
  type        = string
  default     = ""
}
