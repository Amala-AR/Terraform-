#!/bin/bash
# ============================================================
# USER DATA — runs once when EC2 first boots
# Templated by Terraform: ${region}, ${environment}, ${project}
# DO NOT put secrets here — they appear in EC2 console logs.
# Use SSM Parameter Store for secrets instead.
# ============================================================
set -e
exec > /var/log/user-data.log 2>&1  # log everything for debugging

echo "=== Starting user_data for ${project}-${environment} ==="

# ── System update ──────────────────────────────────────────
yum update -y

# ── Core packages ──────────────────────────────────────────
yum install -y \
  ruby \
  wget \
  curl \
  git \
  jq \
  httpd \
  amazon-cloudwatch-agent

# ── CodeDeploy Agent ───────────────────────────────────────
echo "Installing CodeDeploy agent..."
cd /tmp
wget -q https://aws-codedeploy-${region}.s3.${region}.amazonaws.com/latest/install
chmod +x ./install
./install auto
systemctl enable codedeploy-agent
systemctl start codedeploy-agent
echo "CodeDeploy agent status: $(systemctl is-active codedeploy-agent)"

# ── CloudWatch Agent config ────────────────────────────────
# Sends /var/log/messages, /var/log/httpd/*, codedeploy logs to CloudWatch
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWCONFIG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/${project}/${environment}/system",
            "log_stream_name": "{instance_id}/messages"
          },
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "/${project}/${environment}/httpd",
            "log_stream_name": "{instance_id}/access"
          },
          {
            "file_path": "/var/log/httpd/error_log",
            "log_group_name": "/${project}/${environment}/httpd",
            "log_stream_name": "{instance_id}/error"
          },
          {
            "file_path": "/var/log/aws/codedeploy-agent/codedeploy-agent.log",
            "log_group_name": "/${project}/${environment}/codedeploy",
            "log_stream_name": "{instance_id}/agent"
          }
        ]
      }
    }
  }
}
CWCONFIG

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# ── Web server ─────────────────────────────────────────────
systemctl enable httpd
systemctl start httpd

# Default placeholder page until CodeDeploy delivers real app
cat > /var/www/html/index.html << 'HTML'
<html>
  <body>
    <h1>${project} — ${environment}</h1>
    <p>EC2 is up. Waiting for CodeDeploy to deliver the application.</p>
  </body>
</html>
HTML

echo "=== user_data complete ==="
