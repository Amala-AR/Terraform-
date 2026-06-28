# envs/staging.tfvars
# Used by: terraform apply -var-file="envs/staging.tfvars"

project             = "myapp"
environment         = "staging"
aws_region          = "us-east-1"
instance_type       = "t3.small"
root_volume_size    = 30
key_pair_name       = ""
ssh_cidr            = "10.0.0.0/8"  # VPN/internal only
app_port            = 8080
associate_public_ip = true
create_eip          = false
sns_alert_arn       = ""            # no alerts in staging
