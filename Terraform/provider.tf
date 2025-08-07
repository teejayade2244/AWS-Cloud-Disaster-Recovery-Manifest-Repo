terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" 
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23" 
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.12.1" 
    }
  }
}

provider "aws" {
  region = var.primary_region
  alias  = "primary"
}

provider "aws" {
  region = var.secondary_region
  alias  = "secondary"
}

provider "tls" {
  alias = "primary"
}

provider "tls" {
  alias = "secondary"
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
