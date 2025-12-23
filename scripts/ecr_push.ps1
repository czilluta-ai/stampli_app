param(
  [string]$Region = "us-east-1",
  [string]$RepoUrl,
  [string]$Tag = "latest"
)

if (-not $RepoUrl) { Write-Error "RepoUrl is required (e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com/stampli-web-app)"; exit 1 }

$ErrorActionPreference = "Stop"

Write-Host "Logging into ECR..."
aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $RepoUrl.Split('/')[0]

$ImageName = "stampli-web-app"
$FullTag = "$RepoUrl:$Tag"

Write-Host "Building image..."
docker build -t $ImageName .

Write-Host "Tagging image..."
docker tag $ImageName $FullTag

Write-Host "Pushing image..."
docker push $FullTag

Write-Host "Done. Pushed $FullTag"
