# --- EKS Cluster Module Resources ---
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws, aws.primary, aws.secondary]
    }
    tls = {
      source = "hashicorp/tls"
      version = "~> 4.0"
      configuration_aliases = [tls, tls.primary, tls.secondary]
    }
  }
}


# --- IAM Roles for EKS ---

# EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster_role" {
  provider = aws
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
  provider   = aws
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# Attach AmazonEKSServicePolicy to the EKS Cluster Role
resource "aws_iam_role_policy_attachment" "eks_service_policy_attach" {
  provider   = aws
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# EKS Node Group IAM Role
resource "aws_iam_role" "eks_node_role" {
  provider = aws
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
  provider   = aws
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

# Attach AmazonEKS_CNI_Policy to the EKS Node Role (for VPC CNI plugin)
resource "aws_iam_role_policy_attachment" "eks_cni_policy_attach" {
  provider   = aws
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

# Attach AmazonEC2ContainerRegistryReadOnly to the EKS Node Role
resource "aws_iam_role_policy_attachment" "ecr_read_only_policy_attach" {
  provider   = aws
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

# --- EKS Cluster Security Group ---
resource "aws_security_group" "eks_cluster_sg" {
  provider = aws
  name        = "${var.cluster_name}-eks-cluster-sg"
  description = "Security group for EKS cluster control plane communication"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # This dynamically uses the 'allowed_inbound_cidrs' variable,
    # which will be passed from the root module based on VPC CIDRs and TF server's IP.
    cidr_blocks = var.allowed_inbound_cidrs
    description = "Allow inbound HTTPS to EKS API from specified CIDRs (e.g., peered VPCs, Terraform server)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.cluster_name}-eks-cluster-sg"
    Environment = var.environment_tag
  }
}

# --- EKS Cluster ---
resource "aws_eks_cluster" "main" {
  provider = aws
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids # EKS ENIs will be in private subnets
    endpoint_private_access = true  # <<-- CRITICAL: Use private access
    endpoint_public_access  = false # <<-- CRITICAL: Disable public access for security
    public_access_cidrs     = [] # Explicitly empty as public access is disabled.
    # Associate the newly created security group with the EKS cluster endpoint
    security_group_ids = [aws_security_group.eks_cluster_sg.id]
  }

  # Ensure that the EKS cluster is created before the node group
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy_attach,
    aws_iam_role_policy_attachment.eks_service_policy_attach,
    aws_security_group.eks_cluster_sg # Ensure SG is created before cluster uses it
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
  subnet_ids      = var.private_subnet_ids # Worker nodes in private subnets
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }

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

# --- IAM for ALB Ingress Controller Service Account ---
# This section creates the OIDC provider and IAM role for the ALB Ingress Controller
# It's placed here so the role ARN can be outputted from the module
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

# Data source to get the AWSLoadBalancerControllerIAMPolicy
# This assumes the policy is already created in  AWS account (as a managed policy or custom)
# Get current AWS account ID
data "aws_caller_identity" "current" {
  provider = aws.primary
}

# Get details about the primary EKS cluster
data "aws_eks_cluster" "primary" {
  provider = aws.primary
  name     = module.primary_eks.cluster_name
}

# AWS IAM OpenID Connect Provider for EKS
data "aws_iam_openid_connect_provider" "primary" {
  provider = aws.primary
  url      = data.aws_eks_cluster.primary.identity[0].oidc[0].issuer
}

# --- ALB Ingress Controller IAM setup ---

# Existing AWSLoadBalancerControllerIAMPolicy
data "aws_iam_policy" "alb_ingress_controller_policy" {
  provider = aws.primary
  arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/AWSLoadBalancerControllerIAMPolicy"
}

# IAM Role for ALB Ingress Controller
resource "aws_iam_role" "alb_ingress_controller_role" {
  provider = aws.primary
  name     = "${var.cluster_name_prefix}-alb-ingress-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.primary.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_iam_openid_connect_provider.primary.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(data.aws_iam_openid_connect_provider.primary.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name_prefix}-alb-ingress-controller-role"
    Environment = var.environment_tag
  }
}

# Attach ALB policy to role
resource "aws_iam_role_policy_attachment" "alb_ingress_controller_policy_attach" {
  provider   = aws.primary
  policy_arn = data.aws_iam_policy.alb_ingress_controller_policy.arn
  role       = aws_iam_role.alb_ingress_controller_role.name
}

# --- Backend App IAM setup ---

# Trust policy for backend app service account
data "aws_iam_policy_document" "backend_app_trust_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.primary.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.primary.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:default:backend2"]
    }
  }
}

# IAM Role for backend to read DB secrets
resource "aws_iam_role" "backend_secrets_manager_role" {
  provider           = aws.primary
  name               = "${var.cluster_name_prefix}-backend-secrets-manager-role"
  assume_role_policy = data.aws_iam_policy_document.backend_app_trust_policy.json

  tags = {
    Environment = var.environment_tag
    Project     = var.project_name
  }
}

# Policy to allow reading DB secret
data "aws_iam_policy_document" "backend_secrets_manager_policy_document" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [module.primary_database.db_secret_arn]
    effect    = "Allow"
  }
}

# Attach secret access policy
resource "aws_iam_role_policy" "backend_secrets_manager_policy" {
  provider = aws.primary
  name     = "${var.cluster_name_prefix}-backend-secrets-manager-policy"
  role     = aws_iam_role.backend_secrets_manager_role.id
  policy   = data.aws_iam_policy_document.backend_secrets_manager_policy_document.json
}
