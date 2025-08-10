# modules/ecr/variables.tf

variable "project_name" {
  description = "The name of the overall project."
  type        = string
}

variable "environment_tag" {
  description = "The environment for which these ECR repositories are being created (e.g., dev, prod)."
  type        = string
}

variable "region_suffix" {
  description = "A suffix representing the AWS region (e.g., eu-west-2, us-east-1). Used for naming."
  type        = string
}

variable "application_names" {
  description = "A list of application names for which ECR repositories should be created."
  type        = list(string)
}

variable "image_tag_mutability" {
  description = "The tag mutability setting for the repository. Valid values are: MUTABLE or IMMUTABLE."
  type        = string
  default     = "IMMUTABLE" # Good practice for production to prevent accidental tag overwrites
}

variable "scan_on_push" {
  description = "Indicates whether images are scanned for vulnerabilities when pushed to the repository."
  type        = bool
  default     = true
}

variable "lifecycle_policy_rules" {
  description = "A list of map objects defining lifecycle policy rules for the repository."
  type = list(object({
    rulePriority : number # Changed from rule_priority to rulePriority
    description   : string
    selection     : object({
      tag_status : string
      tag_prefix_list : list(string)
      count_type : string
      count_number : number
      count_unit : string
    })
    action : object({
      type : string
    })
  }))
  default = [
    {
      rulePriority = 1 # Changed from rule_priority to rulePriority
      description   = "Delete untagged images after 7 days"
      selection = {
        tag_status      = "untagged"
        tag_prefix_list = [] # No specific prefix
        count_type      = "sinceImagePushed"
        count_number    = 7
        count_unit      = "days"
      }
      action = {
        type = "expire"
      }
    },
    {
      rulePriority = 2 # Changed from rule_priority to rulePriority
      description   = "Keep last 5 images for 'release-' tags"
      selection = {
        tag_status      = "tagged"
        tag_prefix_list = ["release-"]
        count_type      = "imageCountMoreThan"
        count_number    = 5
        count_unit      = "image" # For 'imageCountMoreThan', count_unit must be 'image'
      }
      action = {
        type = "expire"
      }
    }
  ]
}
