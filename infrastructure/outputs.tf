output "alb_dns" {
  value = aws_lb.alb.dns_name
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.cf.domain_name
}

output "ecr_repo_url" {
  value = aws_ecr_repository.app.repository_url
}
