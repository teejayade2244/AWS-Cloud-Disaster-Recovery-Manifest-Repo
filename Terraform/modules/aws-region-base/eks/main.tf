# EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster_role" {
  name     = "${var.cluster_name}-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-eks-cluster-role"
    Environment = var.environment_tag
  }
}

# Attach AmazonEKSClusterPolicy to the EKS Cluster Role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# Attach AmazonEKSServicePolicy to the EKS Cluster Role
resource "aws_iam_role_policy_attachment" "eks_service_policy_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# EKS Node Group IAM Role
resource "aws_iam_role" "eks_node_role" {
  name     = "${var.cluster_name}-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-eks-node-role"
    Environment = var.environment_tag
  }
}

# Attach AmazonEKSWorkerNodePolicy to the EKS Node Role
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

# Attach AmazonEKS_CNI_Policy to the EKS Node Role (for VPC CNI plugin)
resource "aws_iam_role_policy_attachment" "eks_cni_policy_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

# Attach AmazonEC2ContainerRegistryReadOnly to the EKS Node Role
resource "aws_iam_role_policy_attachment" "ecr_read_only_policy_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

# --- EKS Cluster ---
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids         = var.private_subnet_ids 
    endpoint_private_access = true 
    endpoint_public_access  = false
  }

  # Ensure that the EKS cluster is created before the node group
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy_attach,
    aws_iam_role_policy_attachment.eks_service_policy_attach,
  ]

  tags = {
    Name        = var.cluster_name
    Environment = var.environment_tag
  }
}

# --- EKS Node Group ---
resource "aws_eks_node_group" "main" {
  provider = aws
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.private_subnet_ids 
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }

  # Update launch template to enable EBS encryption (optional but recommended)
  # launch_template {
  #   name    = "${var.cluster_name}-node-group-lt"
  #   version = "$Latest"
  # }

  # Ensure the node group is created after the cluster
  depends_on = [
    aws_eks_cluster.main,
    aws_iam_role_policy_attachment.eks_worker_node_policy_attach,
    aws_iam_role_policy_attachment.eks_cni_policy_attach,
    aws_iam_role_policy_attachment.ecr_read_only_policy_attach,
  ]

  tags = {
    Name        = "${var.cluster_name}-node-group"
    Environment = var.environment_tag
    # Required for Kubernetes Cluster Autoscaler to discover the node group
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    "k8s.io/cluster-autoscaler/enabled"             = "true"
  }
}

# --- AWS Load Balancer Controller (Helm Chart) ---
# deploys the ALB Ingress Controller into your EKS cluster
# It requires OIDC provider and IAM role for service account

# Create OIDC provider for the EKS cluster
resource "aws_iam_openid_connect_provider" "main" {
  provider = aws
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc_thumbprint.certificates[0].sha1_fingerprint]
}

# Data source to get the OIDC provider's thumbprint
data "tls_certificate" "eks_oidc_thumbprint" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# IAM Policy for ALB Ingress Controller
data "aws_iam_policy" "alb_ingress_controller_policy" {
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/AWSLoadBalancerControllerIAMPolicy"
}

# IAM Role for ALB Ingress Controller Service Account
resource "aws_iam_role" "alb_ingress_controller_role" {
  name     = "${var.cluster_name}-alb-ingress-controller-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.main.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.main.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(aws_iam_openid_connect_provider.main.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-alb-ingress-controller-role"
    Environment = var.environment_tag
  }
}

# Attach the ALB Ingress Controller Policy to its IAM Role
resource "aws_iam_role_policy_attachment" "alb_ingress_controller_policy_attach" {
  provider   = aws
  policy_arn = data.aws_iam_policy.alb_ingress_controller_policy.arn
  role       = aws_iam_role.alb_ingress_controller_role.name
}


# Primary EKS Cluster Data
data "aws_eks_cluster" "primary" {
  provider = aws.primary
  name     = module.primary_eks.cluster_name
}

# Primary EKS Cluster Auth Data
data "aws_eks_cluster_auth" "primary" {
  provider = aws.primary
  name     = module.primary_eks.cluster_name
}

# Secondary EKS Cluster Data
data "aws_eks_cluster" "secondary" {
  provider = aws.secondary
  name     = module.secondary_eks.cluster_name
}

# Secondary EKS Cluster Auth Data
data "aws_eks_cluster_auth" "secondary" {
  provider = aws.secondary
  name     = module.secondary_eks.cluster_name
}

# --- Dynamic Kubernetes Provider Configuration for Primary EKS ---
provider "kubernetes" {
  alias = "primary"
  host                   = data.aws_eks_cluster.primary.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.primary.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.primary.token
}

# --- Dynamic Kubernetes Provider Configuration for Secondary EKS ---
provider "kubernetes" {
  alias = "secondary"
  host                   = data.aws_eks_cluster.secondary.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.secondary.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.secondary.token
}

# --- Dynamic Helm Provider Configuration for Primary EKS ---
provider "helm" {
  alias = "primary"
  kubernetes {
    host                   = data.aws_eks_cluster.primary.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.primary.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.primary.token
  }
}

# --- Dynamic Helm Provider Configuration for Secondary EKS ---
provider "helm" {
  alias = "secondary"
  kubernetes {
    host                   = data.aws_eks_cluster.secondary.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.secondary.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.secondary.token
  }
}

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
    value = module.primary_eks.alb_ingress_controller_role_arn # This output will be added to EKS module
  }

  # Ensure the Helm chart is deployed after the EKS cluster and IAM role
  depends_on = [
    module.primary_eks,
    # Ensure the required IAM policy for ALB Controller is attached
    # This dependency will be handled by the EKS module's outputs
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
    value = module.secondary_eks.alb_ingress_controller_role_arn # This output will be added to EKS module
  }

  depends_on = [
    module.secondary_eks,
  ]
}