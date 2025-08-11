# Variables for the generic networking module
variable "region" {
  description = "The AWS region where these networking resources will be deployed."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets."
  type        = list(string)
}

variable "environment_tag" {
  description = "Tag for the environment (e.g., Production, DisasterRecovery)."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster for Kubernetes subnet tagging."
  type        = string
}