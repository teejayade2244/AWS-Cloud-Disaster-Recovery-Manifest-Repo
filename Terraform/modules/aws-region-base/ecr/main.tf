resource "aws_ecr_repository" "app_repo" {
  for_each             = toset(var.repository_names) 
  name                 = "${var.project_name}-${each.key}" 
  image_tag_mutability = "IMMUTABLE" 

  image_scanning_configuration {
    scan_on_push = true 
  }

  tags = {
    Name        = "${var.project_name}-${each.key}"
    Environment = var.environment_tag
    Project     = var.project_name
  }
}
