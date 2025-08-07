# --- Deploy ALB Ingress Controller using Helm for Primary EKS ---
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
    value = module.primary_eks.alb_ingress_controller_role_arn # Correctly references module output
  }

  # The helm_release implicitly depends on the helm.primary provider being configured.
  # The helm.primary provider itself depends on the EKS data sources, which depend on module.primary_eks.
  # Therefore, a direct depends_on on the module is sufficient.
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
    value = module.secondary_eks.alb_ingress_controller_role_arn # Correctly references module output
  }

  depends_on = [
    module.secondary_eks,
  ]
}
