
variable "project_name" {
  description = "The name of the project (e.g., aura-flow)."
  type        = string
}

variable "environment_tag" {
  description = "Environment tag for resources (e.g., 'Production', 'DisasterRecovery')."
  type        = string
}

variable "repository_names" {
  description = "A list of repository names to create (e.g., ['backend-app', 'frontend-app'])."
  type        = list(string)
}
