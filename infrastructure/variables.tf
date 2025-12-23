variable "aws_region" {
  description = "AWS region"
  default     = "uu-west-2"
}

variable "ecs_cluster_name" {
  default = "client-ip-cluster"
}

variable "ecs_service_name" {
  default = "client-ip-service"
}

variable "ecr_repo_name" {
  default = "client-ip-app"
}
