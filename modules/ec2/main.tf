# ============================================================
# MODULE: ec2
# Provisions: Security Group, IAM Role + Instance Profile,
#             Key Pair (optional), EBS volume, EC2 instance.
# Called by environments/dev|staging|prod/main.tf
# ============================================================

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

# ── Latest Amazon Linux 2 AMI ──────────────────────────────
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Security Group ─────────────────────────────────────────
resource "aws_security_group" "this" {
  name        = "${var.project}-${var.environment}-sg"
  description = "Security group for ${var.project} ${var.environment} EC2"
  vpc_id      = var.vpc_id

  # SSH — locked to ssh_cidr (open in dev, office IP in prod)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # App port (e.g. Node/Java/Python app running on 8080)
  dynamic "ingress" {
    for_each = var.app_port != 0 ? [var.app_port] : []
    content {
      description = "App port"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-sg"
  })

  lifecycle {
    # Avoid SG destroy/recreate if name already exists
    create_before_destroy = true
  }
}

# ── IAM Role ───────────────────────────────────────────────
resource "aws_iam_role" "ec2" {
  name        = "${var.project}-${var.environment}-ec2-role"
  description = "Role for ${var.project} ${var.environment} EC2 instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.tags
}

# SSM Session Manager — lets you shell into EC2 without SSH keys
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CodeDeploy agent on the instance needs this to pull artifacts
resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}

# CloudWatch agent — push logs and metrics to CloudWatch
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Allow EC2 to read its own SSM parameters (app config, secrets)
resource "aws_iam_role_policy" "ssm_params" {
  name = "${var.project}-${var.environment}-ssm-read"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
      Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project}/${var.environment}/*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-${var.environment}-instance-profile"
  role = aws_iam_role.ec2.name
}

# ── EBS Root Volume ────────────────────────────────────────
# Defined here so we can set size and encryption per env
# Dev: 20GB, Staging: 30GB, Prod: 50GB (set via var.root_volume_size)

# ── EC2 Instance ───────────────────────────────────────────
resource "aws_instance" "this" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  key_name                    = var.key_pair_name != "" ? var.key_pair_name : null
  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size   # 20 dev / 30 staging / 50 prod
    encrypted             = true                   # always encrypt
    delete_on_termination = true

    tags = merge(var.tags, {
      Name = "${var.project}-${var.environment}-root-vol"
    })
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    region      = var.aws_region
    environment = var.environment
    project     = var.project
  }))

  # Real-world lifecycle rules:
  # - ignore AMI changes → prevents EC2 replacement on every AMI update
  # - ignore user_data changes → prevents replacement when you tweak startup script
  #   (use SSM Run Command or CodeDeploy for in-place changes instead)
  lifecycle {
    ignore_changes = [
      ami,
      user_data,
    ]
  }

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-server"
    Environment = var.environment
    # CodeDeploy deployment group filters by this tag
    DeployTarget = "${var.project}-${var.environment}"
  })
}

# ── Elastic IP (prod only) ─────────────────────────────────
# In prod you want a stable IP that survives stop/start.
# In dev/staging, skip it to save cost (~$3.60/mo when attached,
# more expensive when unattached — so only create if needed).
resource "aws_eip" "this" {
  count    = var.create_eip ? 1 : 0
  instance = aws_instance.this.id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-eip"
  })

  lifecycle {
    prevent_destroy = false
  }
}
