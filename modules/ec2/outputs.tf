# ============================================================
# MODULE: ec2 — Outputs
# These are consumed by the environment's main.tf and by
# CodeBuild post_build to capture instance details.
# ============================================================

output "instance_id" {
  description = "EC2 Instance ID — used by CodeDeploy to target deployments"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP (dynamic — changes on stop/start unless EIP is used)"
  value       = aws_instance.this.public_ip
}

output "private_ip" {
  description = "Private IP — stable, use this for internal service communication"
  value       = aws_instance.this.private_ip
}

output "public_dns" {
  description = "Public DNS hostname of the instance"
  value       = aws_instance.this.public_dns
}

output "eip_public_ip" {
  description = "Elastic IP address (stable) — only set when create_eip = true"
  value       = var.create_eip ? aws_eip.this[0].public_ip : null
}

output "security_group_id" {
  description = "ID of the security group attached to the instance"
  value       = aws_security_group.this.id
}

output "iam_role_name" {
  description = "Name of the IAM role attached to the instance"
  value       = aws_iam_role.ec2.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role — needed if other services need to reference it"
  value       = aws_iam_role.ec2.arn
}

output "instance_profile_name" {
  description = "Instance profile name — useful for CodeDeploy deployment group config"
  value       = aws_iam_instance_profile.ec2.name
}

output "ami_id" {
  description = "AMI ID that was used to launch the instance"
  value       = data.aws_ami.amazon_linux_2.id
}

output "deploy_tag" {
  description = "The tag value CodeDeploy uses to find this instance"
  value       = "${var.project}-${var.environment}"
}
