resource "aws_ecr_repository" "app_repo" {
  for_each = toset(var.application_names) #
  name =  "${var.project_name}-${var.environment_tag}-${var.region_suffix}-${each.key}"

  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = {
    Name        = var.project_name
    Environment = var.environment_tag
  }
}

resource "aws_ecr_lifecycle_policy" "app_repo_policy" {
  for_each = aws_ecr_repository.app_repo

  repository = each.value.name

  policy = jsonencode({
    rules = var.lifecycle_policy_rules 
  })
}
