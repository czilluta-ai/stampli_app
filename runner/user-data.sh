#!/bin/bash
set -euo pipefail

REPO_URL="##REPO_URL##"           # e.g., https://github.com/owner/repo
RUNNER_TOKEN="##RUNNER_TOKEN##"   # Registration token (valid ~1 hour)
RUNNER_NAME="##RUNNER_NAME##"     # e.g., aws-ec2-runner-1
RUNNER_LABELS="##RUNNER_LABELS##" # e.g., self-hosted,ec2

# Update and install deps
if command -v dnf >/dev/null 2>&1; then
  dnf update -y
  dnf install -y jq tar curl
else
  yum update -y
  yum install -y jq tar curl
fi

# Create runner user and working dir
id -u githubrunner >/dev/null 2>&1 || useradd -m -r -s /bin/bash githubrunner
mkdir -p /opt/actions-runner
chown -R githubrunner:githubrunner /opt/actions-runner
cd /opt/actions-runner

# Download latest actions runner
LATEST_TAG=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name)
FILE="actions-runner-linux-x64-${LATEST_TAG#v}.tar.gz"
curl -L -o "$FILE" "https://github.com/actions/runner/releases/download/${LATEST_TAG}/${FILE}"
tar xzf "$FILE"

# Install runner dependencies
./bin/installdependencies.sh || true

# Configure and install as a service (runs under githubrunner)
su - githubrunner -c "cd /opt/actions-runner && ./config.sh --url '$REPO_URL' --token '$RUNNER_TOKEN' --name '$RUNNER_NAME' --labels '$RUNNER_LABELS' --unattended --replace"
./svc.sh install githubrunner
./svc.sh start

# Enable SSM agent if present (Amazon Linux 2/2023 images have it)
systemctl enable amazon-ssm-agent || true
systemctl start amazon-ssm-agent || true

# Basic cloud-init marker
echo "Runner setup complete" > /var/log/github-runner-setup.log
