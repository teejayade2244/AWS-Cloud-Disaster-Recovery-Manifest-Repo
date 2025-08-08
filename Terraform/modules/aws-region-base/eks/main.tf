# --- EKS Cluster Module Resources ---

# Explicitly declare the required providers for this module
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use a compatible version
    }
    tls = { # TLS provider is still needed for OIDC thumbprint
      source  = "hashicorp/tls"
      version = "~> 4.0" # Use a compatible version
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
# This assumes the policy is already created in your AWS account (as a managed policy or custom)
# If not, you would need to define it as a resource here.
data "aws_iam_policy" "alb_ingress_controller_policy" {
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/AWSLoadBalancerControllerIAMPolicy"
}

# IAM Role for ALB Ingress Controller Service Account
resource "aws_iam_role" "alb_ingress_controller_role" {
  provider = aws
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

# Data source for current AWS account ID
data "aws_caller_identity" "current" {
  provider = aws
}
