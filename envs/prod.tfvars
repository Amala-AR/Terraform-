# envs/prod.tfvars
# Values like ssh_cidr and sns_alert_arn come from SSM at build time.
# The buildspec writes this file dynamically — never commit real values.

project             = "myapp"
environment         = "prod"
aws_region          = "us-east-1"
instance_type       = "t3.medium"
root_volume_size    = 50
key_pair_name       = "myapp-prod-keypair"
ssh_cidr            = "203.0.113.0/24"   # office IP — set via SSM in pipeline
app_port            = 8080
associate_public_ip = false              # prod uses EIP only
create_eip          = true
sns_alert_arn       = "arn:aws:sns:us-east-1:123456789012:myapp-prod-alerts"
