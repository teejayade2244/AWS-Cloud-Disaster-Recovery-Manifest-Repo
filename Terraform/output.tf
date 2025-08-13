# --- Primary Region Networking Outputs ---
output "primary_vpc_id" {
  description = "The ID of the VPC in the primary region."
  value       = module.primary_networking.vpc_id
}

output "primary_public_subnet_ids" {
  description = "List of IDs of the public subnets in the primary region."
  value       = module.primary_networking.public_subnet_ids
}

output "primary_private_subnet_ids" {
  description = "List of IDs of the private subnets in the primary region."
  value       = module.primary_networking.private_subnet_ids
}

output "primary_availability_zones" {
  description = "List of Availability Zones used in the primary region."
  value       = module.primary_networking.availability_zones
}

# --- Secondary Region Networking Outputs ---
output "secondary_vpc_id" {
  description = "The ID of the VPC in the secondary region."
  value       = module.secondary_networking.vpc_id
}

output "secondary_public_subnet_ids" {
  description = "List of IDs of the public subnets in the secondary region."
  value       = module.secondary_networking.public_subnet_ids
}

output "secondary_private_subnet_ids" {
  description = "List of IDs of the private subnets in the secondary region."
  value       = module.secondary_networking.private_subnet_ids
}

output "secondary_availability_zones" {
  description = "List of Availability Zones used in the secondary region."
  value       = module.secondary_networking.availability_zones
}

# --- Primary Region EKS Outputs ---
output "primary_eks_cluster_name" {
  description = "The name of the EKS cluster in the primary region."
  value       = module.primary_eks.cluster_name
}

output "primary_eks_cluster_endpoint" {
  description = "The endpoint for the EKS cluster in the primary region."
  value       = module.primary_eks.cluster_endpoint
}

output "primary_eks_kubeconfig_command" {
  description = "Command to update kubeconfig for primary EKS cluster."
  value       = "aws eks update-kubeconfig --region ${var.primary_region} --name ${module.primary_eks.cluster_name}"
}

output "primary_eks_cluster_certificate_authority_data" {
  description = "The base64 encoded certificate authority data for the primary EKS cluster."
  value       = module.primary_eks.cluster_certificate_authority_data # Correctly references module output
}

output "primary_alb_ingress_controller_role_arn" {
  description = "ARN of the IAM role for the ALB Ingress Controller Service Account in the primary region."
  value       = module.primary_eks.alb_ingress_controller_role_arn # Correctly references module output
}

# --- Secondary Region EKS Outputs ---
output "secondary_eks_cluster_name" {
  description = "The name of the EKS cluster in the secondary region."
  value       = module.secondary_eks.cluster_name
}

output "secondary_eks_cluster_endpoint" {
  description = "The endpoint for the EKS cluster in the secondary region."
  value       = module.secondary_eks.cluster_endpoint
}

output "secondary_eks_kubeconfig_command" {
  description = "Command to update kubeconfig for secondary EKS cluster."
  value       = "aws eks update-kubeconfig --region ${var.secondary_region} --name ${module.secondary_eks.cluster_name}"
}

output "secondary_eks_cluster_certificate_authority_data" {
  description = "The base64 encoded certificate authority data for the secondary EKS cluster."
  value       = module.secondary_eks.cluster_certificate_authority_data # Correctly references module output
}

output "secondary_alb_ingress_controller_role_arn" {
  description = "ARN of the IAM role for the ALB Ingress Controller Service Account in the secondary region."
  value       = module.secondary_eks.alb_ingress_controller_role_arn # Correctly references module output
}

# Add these to your existing output.tf file

# --- Database Outputs ---
output "primary_db_endpoint" {
  description = "The endpoint of the primary RDS database."
  value       = module.primary_database.db_instance_endpoint
}

output "secondary_db_endpoint" {
  description = "The endpoint of the secondary RDS database (read replica)."
  value       = module.secondary_database.db_instance_endpoint
}

output "primary_db_secret_arn" {
  description = "ARN of the primary database secret."
  value       = module.primary_database.db_secret_arn
}

output "secondary_db_secret_arn" {
  description = "ARN of the secondary database secret."
  value       = module.secondary_database.db_secret_arn
}

output "primary_db_secret_name" {
  description = "Name of the primary database secret for Kubernetes."
  value       = module.primary_database.db_secret_name
}

output "secondary_db_secret_name" {
  description = "Name of the secondary database secret for Kubernetes."
  value       = module.secondary_database.db_secret_name
}

