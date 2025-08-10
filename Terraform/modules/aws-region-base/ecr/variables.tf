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