# Self-hosted GitHub Runner on AWS (Quick)

This folder includes a minimal setup to launch a self-hosted GitHub Actions runner on an EC2 instance using a one-shot PowerShell script.

## Steps
- Generate a runner registration token (valid ~1 hour):
  - Repo-level: GitHub → your repo → Settings → Actions → Runners → New self-hosted runner → Linux → x64.
  - Org-level: Organization → Settings → Actions → Runners → New.

- Launch the EC2 runner from Windows PowerShell:

```powershell
# Set your values
$Region = "us-east-1"
$RepoUrl = "https://github.com/<owner>/<repo>"
$RunnerToken = "<paste-registration-token>"
$RunnerName = "aws-ec2-runner-1"
$RunnerLabels = "self-hosted,ec2"

# Run the helper script
../scripts/setup_runner.ps1 -Region $Region -RepoUrl $RepoUrl -RunnerToken $RunnerToken -RunnerName $RunnerName -RunnerLabels $RunnerLabels
```

- After ~1–2 minutes, confirm the runner appears under GitHub → Settings → Actions → Runners.

## Use the runner in workflows
Add `runs-on` to match your labels:

```yaml
jobs:
  build:
    runs-on: [self-hosted, ec2]
    steps:
      - uses: actions/checkout@v4
      - run: echo "Running on self-hosted EC2"
```

## Notes
- Script creates a small `t3.micro` EC2 in your default VPC, installs the latest GitHub Actions runner, registers it, and starts it as a service.
- Security group allows SSH only from your current public IP; change or remove `-KeyName` if you don't need SSH.
- Instance gets SSM managed policy for remote access via AWS Systems Manager.
- User data template is at `runner/user-data.sh` and uses placeholders replaced by the script.
- Clean up: terminate the EC2 instance, delete the SG, IAM role, and instance profile if no longer needed.
