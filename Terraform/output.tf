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
