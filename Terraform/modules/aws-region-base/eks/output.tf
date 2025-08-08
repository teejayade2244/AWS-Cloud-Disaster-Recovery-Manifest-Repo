# Outputs for the EKS module

output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS cluster."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "The base64 encoded certificate authority data for the EKS cluster."
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "oidc_issuer" {
  description = "The OIDC issuer URL for the EKS cluster."
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by EKS worker nodes."
  value       = var.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by EKS Load Balancers."
  value       = var.public_subnet_ids
}

output "alb_ingress_controller_role_arn" {
  description = "ARN of the IAM role for the ALB Ingress Controller Service Account."
  value       = aws_iam_role.alb_ingress_controller_role.arn
}
