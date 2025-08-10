# modules/ecr/main.tf

# Declare the required providers for this module.
# This makes the module self-contained in terms of its provider dependencies.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Specify a compatible version range for the AWS provider
    }
  }
}

# This resource creates multiple ECR repositories based on the 'application_names' list.
# The 'for_each' meta-argument is used to iterate over the list, creating a separate
# ECR repository resource for each application name.
resource "aws_ecr_repository" "app_repo" {
  for_each = toset(var.application_names) # Converts the list to a set for iteration

  # Naming convention: project-environment-region-appname
  # Convert environment_tag to lowercase to satisfy ECR naming constraints.
  # Example: aura-flow-production-eu-west-2-frontend-app
  name = "${var.project_name}-${lower(var.environment_tag)}-${var.region_suffix}-${each.key}"

  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment_tag # Keep original case for tags if desired
    Region      = var.region_suffix
    Application = each.key
  }
}

# This resource applies a lifecycle policy to each created ECR repository.
# The 'for_each' is used again to ensure each repository gets its own policy.
resource "aws_ecr_lifecycle_policy" "app_repo_policy" {
  for_each = aws_ecr_repository.app_repo # Iterates over the created repositories

  repository = each.value.name # Refers to the name of the ECR repository

  policy = jsonencode({
    rules = var.lifecycle_policy_rules # Uses the rules defined in variables
  })
}
