output "repository_urls" {
  description = "A map of ECR repository URLs, keyed by repository name."
  value       = { for name, repo in aws_ecr_repository.app_repo : name => repo.repository_url }
}
