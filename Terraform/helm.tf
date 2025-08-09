# helm-deployments.tf

# Primary EKS Cluster Data
data "aws_eks_cluster" "primary" {
  provider = aws.primary
  name     = module.primary_eks.cluster_name
  # Add explicit dependency to ensure the EKS module has finished creating the cluster
  depends_on = [module.primary_eks]
}

# Primary EKS Cluster Auth Data
data "aws_eks_cluster_auth" "primary" {
  provider = aws.primary
  name     = module.primary_eks.cluster_name
  # Add explicit dependency
  depends_on = [module.primary_eks]
}

# Secondary EKS Cluster Data
data "aws_eks_cluster" "secondary" {
  provider = aws.secondary
  name     = module.secondary_eks.cluster_name
  # Add explicit dependency
  depends_on = [module.secondary_eks]
}

# Secondary EKS Cluster Auth Data
data "aws_eks_cluster_auth" "secondary" {
  provider = aws.secondary
  name     = module.secondary_eks.cluster_name
  # Add explicit dependency
  depends_on = [module.secondary_eks]
}

# Deploy ALB Ingress Controller using Helm for Primary EKS
resource "helm_release" "primary_aws_load_balancer_controller" {
  provider = helm.primary
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.0" # Use a compatible version for your K8s version

  set {
    name  = "clusterName"
    value = module.primary_eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.primary_eks.alb_ingress_controller_role_arn
  }

  # --- NEW: Explicitly set vpcID to avoid metadata introspection issues ---
  set {
    name  = "vpcID"
    value = module.primary_networking.vpc_id # Retrieve VPC ID from networking module output
  }

  # Dependencies are handled by the Helm provider's configuration and the EKS module
  depends_on = [
    module.primary_eks,
  ]
}

# --- Deploy ALB Ingress Controller using Helm for Secondary EKS ---
resource "helm_release" "secondary_aws_load_balancer_controller" {
  provider = helm.secondary
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.0" # Use a compatible version for your K8s version

  set {
    name  = "clusterName"
    value = module.secondary_eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.secondary_eks.alb_ingress_controller_role_arn
  }

  # --- NEW: Explicitly set vpcID to avoid metadata introspection issues ---
  set {
    name  = "vpcID"
    value = module.secondary_networking.vpc_id # Retrieve VPC ID from networking module output
  }

  # Dependencies are handled by the Helm provider's configuration and the EKS module
  depends_on = [
    module.secondary_eks,
  ]
}