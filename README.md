# Minimal CloudFront → ALB → ECS (Fargate) → Web App

This repo deploys a minimal path:

CloudFront → ALB (HTTP) → ECS service (2 tasks) → Node web app that returns an HTML page with the client's public IP extracted from `X-Forwarded-For`.

## App
- `GET /` returns a simple HTML card with the detected IP
- `GET /health` returns `200 OK` for ALB health checks

The IP is the first public IPv4 found in `X-Forwarded-For` (or fallback headers). Private and reserved ranges are ignored.

## Prerequisites
- AWS account + credentials configured (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_DEFAULT_REGION` or ~/.aws/config)
- Terraform >= 1.5
- Docker
- AWS CLI

## Deploy steps (minimal)

1. Initialize Terraform and create ECR repository:

```powershell
cd terraform
terraform init
terraform apply -target=aws_ecr_repository.app -auto-approve
```

2. Build and push the image to ECR (replace values):

```powershell
$RepoUrl = (terraform output -raw ecr_repo_url)
../scripts/ecr_push.ps1 -Region us-east-1 -RepoUrl $RepoUrl -Tag latest
```

3. Deploy infra with the image URI (single task on Fargate):

```powershell
terraform apply -var "image_uri=$RepoUrl:latest" -auto-approve
```

4. Access the app:
- ALB: `terraform output alb_dns_name`
- CloudFront: `terraform output cloudfront_domain_name`

CloudFront will send the client IP in `X-Forwarded-For`; the app extracts the first public IP and displays it.

## Local test

```powershell
npm install
npm start
```

Then:

```powershell
# Simulate proxy chain; first value is used
curl -H "X-Forwarded-For: 1.2.3.4, 10.0.0.1" http://localhost:3000/
```

## GitHub Actions CI/CD

Create repository secrets:
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` (e.g., `us-east-1`)
- `ECR_REPOSITORY` (e.g., `stampli-web-app`)
- `ECS_CLUSTER` (e.g., `stampli-ecs-cluster`)
- `ECS_SERVICE` (e.g., `stampli-web-service`)
- `ECS_TASK_DEFINITION` (e.g., `stampli-web-app`)
- `CLOUDFRONT_DISTRIBUTION_ID` (from Terraform output or console)

On push to `main`, the workflow at `.github/workflows/deploy.yml` will:
- Build and push the Docker image to ECR (tagged with commit SHA)
- Register a new ECS task definition revision with the new image
- Update the ECS service and wait for it to stabilize
- Invalidate CloudFront cache for `/`

## Notes
- Uses default VPC and subnets for simplicity.
- ALB is internet-facing on port 80.
- CloudFront uses the default certificate and HTTP origin to the ALB.
- ECS service runs 1 Fargate task with `assign_public_ip = true`.

## How client IP is detected
- If `X-Forwarded-For` exists, the first comma-separated value is used.
- Otherwise, falls back to the remote socket address.
