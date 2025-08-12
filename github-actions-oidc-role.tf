variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "github_organization" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
}

variable "application_names" {
  description = "List of application names for ECR repositories"
  type        = list(string)
}


data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["7560d6f40fa55195f740ee2b7b7c0b4836cbe103"] # NEW thumbprint

  tags = {
    Name        = "${var.project_name}-github-oidc-provider"
    Environment = "CI/CD"
  }
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions_oidc_role" {
  name = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.github_actions.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "${replace(aws_iam_openid_connect_provider.github_actions.url, "https://", "")}:sub" = [
              "repo:${var.github_organization}/${var.github_repository}:ref:refs/heads/main",
              "repo:${var.github_organization}/${var.github_repository}:pull_request",
              "repo:${var.github_organization}/${var.github_repository}:environment:prod"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-github-actions-role"
    Environment = "CI/CD"
  }
}

# ECR Push Policy
resource "aws_iam_role_policy" "ecr_push_policy" {
  name = "${var.project_name}-github-actions-ecr-push"
  role = aws_iam_role.github_actions_oidc_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:GetAuthorizationToken"
        ],
        Resource = [for name in var.application_names : "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}-${name}"]
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:CreateRepository",
          "ecr:DescribeRepositories"
        ],
        Resource = "*"
      }
    ]
  })
}

# EKS Policies
data "aws_iam_policy" "eks_cluster_policy" {
  arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_iam_policy" "eks_worker_node_policy" {
  arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

data "aws_iam_policy" "eks_cni_policy" {
  arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "github_actions_eks_cluster_attach" {
  policy_arn = data.aws_iam_policy.eks_cluster_policy.arn
  role       = aws_iam_role.github_actions_oidc_role.name
}

resource "aws_iam_role_policy_attachment" "github_actions_eks_worker_node_attach" {
  policy_arn = data.aws_iam_policy.eks_worker_node_policy.arn
  role       = aws_iam_role.github_actions_oidc_role.name
}

resource "aws_iam_role_policy_attachment" "github_actions_eks_cni_attach" {
  policy_arn = data.aws_iam_policy.eks_cni_policy.arn
  role       = aws_iam_role.github_actions_oidc_role.name
}

# outputs.tf
output "github_actions_iam_role_arn" {
  description = "The ARN of the IAM role for GitHub Actions to assume"
  value       = aws_iam_role.github_actions_oidc_role.arn
}

output "github_oidc_provider_arn" {
  description = "The ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}