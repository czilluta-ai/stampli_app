variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ecr_repo_name" {
  description = "ECR repository name"
  type        = string
  default     = "stampli-web-app"
}

variable "image_uri" {
  description = "Full image URI, e.g. <account>.dkr.ecr.<region>.amazonaws.com/stampli-web-app:latest"
  type        = string
}
