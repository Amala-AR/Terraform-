# ============================================================
# MODULE: ec2 — Input Variables
# ============================================================

# ── Required ───────────────────────────────────────────────

variable "project" {
  description = "Project name — used as prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment: dev | staging | prod"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod"
  }
}

variable "aws_region" {
  description = "AWS region where resources are created"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EC2 instance will be launched"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the EC2 instance will be launched"
  type        = string
}

# ── Optional with sensible defaults ────────────────────────

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"

  # Prevent accidentally using huge instances
  validation {
    condition = contains([
      "t3.micro", "t3.small", "t3.medium", "t3.large",
      "t3a.micro", "t3a.small", "t3a.medium",
      "m5.large", "m5.xlarge", "m5.2xlarge"
    ], var.instance_type)
    error_message = "instance_type must be an approved type. Add more in variables.tf if needed."
  }
}

variable "key_pair_name" {
  description = "Name of an existing EC2 Key Pair for SSH. Leave empty to skip (use SSM Session Manager instead)."
  type        = string
  default     = ""
}

variable "ssh_cidr" {
  description = "CIDR block allowed for SSH ingress. Use your office IP in prod: x.x.x.x/32"
  type        = string
  default     = "0.0.0.0/0"
}

variable "app_port" {
  description = "Optional application port to open (e.g. 8080 for Node/Java app). Set 0 to skip."
  type        = number
  default     = 0
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB. Recommended: 20 dev, 30 staging, 50 prod"
  type        = number
  default     = 20
}

variable "associate_public_ip" {
  description = "Whether to assign a public IP. True for dev/staging, False for prod (use EIP instead)."
  type        = bool
  default     = true
}

variable "create_eip" {
  description = "Create an Elastic IP for stable public IP (recommended for prod only)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Map of tags applied to every resource in this module"
  type        = map(string)
  default     = {}
}
