# --- EKS Cluster Module Variables ---

variable "region" {
  description = "The AWS region for the EKS cluster."
  type        = string
}

variable "environment_tag" {
  description = "Environment tag for resources (e.g., 'Production', 'DisasterRecovery')."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the EKS cluster will be deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "A list of private subnet IDs for EKS worker nodes."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "A list of public subnet IDs for EKS Load Balancers."
  type        = list(string)
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes."
  type        = string
}

variable "node_group_desired_size" {
  description = "Desired number of worker nodes in the EKS node group."
  type        = number
}

variable "node_group_max_size" {
  description = "Maximum number of worker nodes in the EKS node group."
  type        = number
}

variable "node_group_min_size" {
  description = "Minimum number of worker nodes in the EKS node group."
  type        = number
}

# New variable for inbound CIDRs to the EKS API endpoint
variable "allowed_inbound_cidrs" {
  description = "List of CIDR blocks allowed to access the EKS cluster API endpoint (port 443)."
  type        = list(string)
}
