# envs/dev.tfvars
# Used by: terraform apply -var-file="envs/dev.tfvars"

project             = "myapp"
environment         = "dev"
aws_region          = "us-east-1"
instance_type       = "t3.micro"
root_volume_size    = 20
key_pair_name       = ""
ssh_cidr            = "0.0.0.0/0"   # open in dev
app_port            = 8080
associate_public_ip = true
create_eip          = false
sns_alert_arn       = ""            # no alerts in dev
