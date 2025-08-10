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
    rulePriority : number
    description   : string
    selection     : object({
      tagStatus     : string # Changed from tag_status to tagStatus
      tagPrefixList : list(string) # Changed from tag_prefix_list to tagPrefixList
      countType     : string # Changed from count_type to countType
      countNumber   : number # Changed from count_number to countNumber
      countUnit     : string # Changed from count_unit to countUnit
    })
    action : object({
      type : string
    })
  }))
  default = [
    {
      rulePriority = 1
      description   = "Delete untagged images after 7 days"
      selection = {
        tagStatus     = "untagged" # Changed from tag_status to tagStatus
        tagPrefixList = [] # Changed from tag_prefix_list to tagPrefixList
        countType     = "sinceImagePushed" # Changed from count_type to countType
        countNumber   = 7 # Changed from count_number to countNumber
        countUnit     = "days" # Changed from count_unit to countUnit
      }
      action = {
        type = "expire"
      }
    },
    {
      rulePriority = 2
      description   = "Keep last 5 images for 'release-' tags"
      selection = {
        tagStatus     = "tagged" # Changed from tag_status to tagStatus
        tagPrefixList = ["release-"] # Changed from tag_prefix_list to tagPrefixList
        countType     = "imageCountMoreThan" # Changed from count_type to countType
        countNumber   = 5 # Changed from count_number to countNumber
        countUnit     = "image"
      }
      action = {
        type = "expire"
      }
    }
  ]
}
