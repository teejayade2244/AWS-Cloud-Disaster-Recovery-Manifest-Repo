terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" 
    }
  }
}

resource "aws_ecr_repository" "app_repo" {
  for_each = toset(var.application_names) 
  name = "${var.project_name}-${lower(var.environment_tag)}-${var.region_suffix}-${each.key}"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment_tag 
    Region      = var.region_suffix
    Application = each.key
  }
}

resource "aws_ecr_lifecycle_policy" "app_repo_policy" {
  for_each = aws_ecr_repository.app_repo 
  repository = each.value.name 
  
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Delete untagged images after 7 days"
        selection = {
          tagStatus     = "untagged"
          countType     = "sinceImagePushed"
          countNumber   = 7
          countUnit     = "days"
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 5 images for 'release-' tags"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["release-"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}