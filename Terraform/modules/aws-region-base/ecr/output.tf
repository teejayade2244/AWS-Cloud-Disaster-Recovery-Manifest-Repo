
output "repository_arns" {
  description = "A map of ECR repository ARNs, keyed by application name."
  value       = { for k, v in aws_ecr_repository.app_repo : k => v.arn }
}

output "repository_urls" {
  description = "A map of ECR repository URLs, keyed by application name."
  value       = { for k, v in aws_ecr_repository.app_repo : k => v.repository_url }
}
