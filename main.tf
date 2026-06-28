# ============================================================
# ROOT main.tf — ONE file, used by dev, staging, AND prod.
# The environment is controlled entirely by which .tfvars
# file you pass:
#
#   terraform apply -var-file="envs/dev.tfvars"
#   terraform apply -var-file="envs/staging.tfvars"
#   terraform apply -var-file="envs/prod.tfvars"
#
# In CodeBuild, the pipeline sets ENVIRONMENT=dev|staging|prod
# and the buildspec runs:
#   terraform apply -var-file="envs/${ENVIRONMENT}.tfvars"
# ============================================================

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }

  # Backend is configured dynamically at init time by buildspec:
  # terraform init -backend-config="key=myapp/${ENVIRONMENT}/terraform.tfstate"
  backend "s3" {
    bucket         = ""   # injected at init via -backend-config
    key            = ""   # injected at init via -backend-config
    region         = ""   # injected at init via -backend-config
    dynamodb_table = ""   # injected at init via -backend-config
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

# ── Data Sources ───────────────────────────────────────────
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ── Call the EC2 module ────────────────────────────────────
# This is the ONLY place the module is called.
# All env differences come through variables — no duplication.
module "ec2" {
  source = "./modules/ec2"

  project             = var.project
  environment         = var.environment
  aws_region          = var.aws_region
  vpc_id              = data.aws_vpc.default.id
  subnet_id           = tolist(data.aws_subnets.default.ids)[0]
  instance_type       = var.instance_type
  root_volume_size    = var.root_volume_size
  key_pair_name       = var.key_pair_name
  ssh_cidr            = var.ssh_cidr
  app_port            = var.app_port
  associate_public_ip = var.associate_public_ip
  create_eip          = var.create_eip
  tags                = local.common_tags
}

# ── Prod-only CloudWatch Alarm ─────────────────────────────
# count = 1 in prod, 0 in dev/staging
# This is how you add prod-only resources WITHOUT a separate main.tf
resource "aws_cloudwatch_metric_alarm" "ec2_down" {
  count = var.environment == "prod" ? 1 : 0

  alarm_name          = "${var.project}-${var.environment}-ec2-down"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Prod EC2 status check failed"
  alarm_actions       = [var.sns_alert_arn]

  dimensions = {
    InstanceId = module.ec2.instance_id
  }
}

# ── Locals ─────────────────────────────────────────────────
locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
    CostCenter  = "engineering"
    AutoStop    = var.environment != "prod" ? "true" : "false"
  }
}

# ── Outputs ────────────────────────────────────────────────
output "instance_id"  { value = module.ec2.instance_id }
output "public_ip"    { value = module.ec2.public_ip }
output "private_ip"   { value = module.ec2.private_ip }
output "deploy_tag"   { value = module.ec2.deploy_tag }
output "eip_public_ip" {
  value = var.create_eip ? module.ec2.eip_public_ip : "N/A (no EIP in ${var.environment})"
}
