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
    security_group_ids = [aws_security_group.eks_cluster_sg.id]
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


# Data source for current AWS account ID
data "aws_caller_identity" "current" {
  provider = aws
}


# --- EKS Cluster Security Group ---
# This security group will be associated with the EKS cluster's ENIs
# to control access to the Kubernetes API endpoint.
resource "aws_security_group" "eks_cluster_sg" {
  provider = aws
  name        = "${var.cluster_name}-eks-cluster-sg"
  description = "Security group for EKS cluster control plane communication"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # Allow access from your current IP for testing.
    # In production, restrict this to specific trusted IPs (e.g., bastion host, CI/CD).
    # You can get your current public IP by visiting "what is my ip" on Google.
    # For broader testing, you can use "0.0.0.0/0" but this is NOT recommended for production.
    cidr_blocks = ["0.0.0.0/0"] # <<-- CONSIDER REPLACING WITH YOUR PUBLIC IP CIDR (e.g., "X.X.X.X/32")
    description = "Allow inbound HTTPS to EKS API from specified CIDRs"
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