param(
  [string]$Region = "us-east-1",
  [string]$RepoUrl,
  [string]$RunnerToken,
  [string]$RunnerName = "aws-ec2-runner-1",
  [string]$RunnerLabels = "self-hosted,ec2",
  [string]$VpcId = $null,
  [string]$SubnetId = $null,
  [string]$InstanceType = "t3.micro",
  [string]$KeyName = $null
)

$ErrorActionPreference = "Stop"
if (-not $RepoUrl) { Write-Error "RepoUrl is required (e.g. https://github.com/owner/repo)"; exit 1 }
if (-not $RunnerToken) { Write-Error "RunnerToken is required (from GitHub UI: Settings → Actions → Runners → New)"; exit 1 }

Write-Host "Configuring AWS region $Region"
aws configure set region $Region

# Discover default VPC and a subnet if not provided
if (-not $VpcId) {
  $VpcId = aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text
}
if (-not $SubnetId) {
  $SubnetId = aws ec2 describe-subnets --filters Name=vpc-id,Values=$VpcId --query 'Subnets[0].SubnetId' --output text
}

# Get caller IP for SSH allowlist
$MyIp = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com").Trim()
$Cidr = "$MyIp/32"

Write-Host "Creating security group..."
$SgId = aws ec2 create-security-group --group-name github-runner-sg --description "SSH from my IP; egress all" --vpc-id $VpcId --query 'GroupId' --output text
aws ec2 authorize-security-group-ingress --group-id $SgId --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp='$Cidr'}]"
aws ec2 authorize-security-group-egress --group-id $SgId --ip-permissions "IpProtocol=-1,FromPort=0,ToPort=0,IpRanges=[{CidrIp='0.0.0.0/0'}]"

Write-Host "Creating IAM role and instance profile for SSM..."
$Trust = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam create-role --role-name github-runner-ec2-role --assume-role-policy-document $Trust | Out-Null
aws iam attach-role-policy --role-name github-runner-ec2-role --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
Start-Sleep -Seconds 5
aws iam create-instance-profile --instance-profile-name github-runner-ec2-profile | Out-Null
aws iam add-role-to-instance-profile --instance-profile-name github-runner-ec2-profile --role-name github-runner-ec2-role

Write-Host "Resolving latest Amazon Linux 2023 AMI..."
$AmiId = aws ec2 describe-images --owners amazon --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text

Write-Host "Preparing user data..."
$UserDataTemplate = Get-Content -Raw -Path "runner/user-data.sh"
$UserData = $UserDataTemplate.Replace("##REPO_URL##", $RepoUrl).Replace("##RUNNER_TOKEN##", $RunnerToken).Replace("##RUNNER_NAME##", $RunnerName).Replace("##RUNNER_LABELS##", $RunnerLabels)
$TmpUserData = New-TemporaryFile
Set-Content -Path $TmpUserData -Value $UserData -NoNewline

Write-Host "Launching EC2 instance..."
$RunOut = aws ec2 run-instances `
  --image-id $AmiId `
  --instance-type $InstanceType `
  --iam-instance-profile Name=github-runner-ec2-profile `
  --security-group-ids $SgId `
  --subnet-id $SubnetId `
  --key-name $KeyName `
  --user-data (Get-Content -Raw $TmpUserData) `
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=github-actions-runner}]" `
  --query 'Instances[0].{InstanceId:InstanceId,PublicDnsName:PublicDnsName,PrivateIpAddress:PrivateIpAddress}' `
  --output json | ConvertFrom-Json

Write-Host "Instance started: $($RunOut.InstanceId)"
Write-Host "Public DNS: $($RunOut.PublicDnsName)"
Write-Host "Private IP: $($RunOut.PrivateIpAddress)"
Write-Host "It may take ~1-2 minutes for the runner to register."
