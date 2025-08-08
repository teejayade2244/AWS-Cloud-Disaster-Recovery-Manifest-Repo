# Variables for the generic VPC Peering module

variable "primary_region" {
  description = "The AWS region of the primary VPC."
  type        = string
}

variable "secondary_region" {
  description = "The AWS region of the secondary VPC."
  type        = string
}

variable "primary_vpc_id" {
  description = "ID of the primary VPC."
  type        = string
}

variable "primary_vpc_cidr" {
  description = "CIDR block of the primary VPC."
  type        = string
}

variable "primary_private_subnet_ids" {
  description = "List of private subnet IDs in the primary VPC."
  type        = list(string)
}

variable "primary_public_subnet_ids" {
  description = "List of public subnet IDs in the primary VPC."
  type        = list(string)
}

variable "secondary_vpc_id" {
  description = "ID of the secondary VPC."
  type        = string
}

variable "secondary_vpc_cidr" {
  description = "CIDR block of the secondary VPC."
  type        = string
}

variable "secondary_private_subnet_ids" {
  description = "List of private subnet IDs in the secondary VPC."
  type        = list(string)
}

variable "secondary_public_subnet_ids" {
  description = "List of public subnet IDs in the secondary VPC."
  type        = list(string)
}
