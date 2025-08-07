
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
      version = "3.0.2"
    }
  }
}

provider "aws" {
  region = var.primary_region
  alias  = "primary" # Alias to distinguish this provider instance
}

# Configure the AWS provider for the secondary region
provider "aws" {
  region = var.secondary_region
  alias  = "secondary" # Alias to distinguish this provider instance
}

# Configure the TLS provider for OIDC thumbprint
provider "tls" {
  alias = "primary"
}

provider "tls" {
  alias = "secondary"
}

    # Configure the Kubernetes provider for the primary EKS cluster
    # This provider's configuration will be dynamically set after the EKS cluster is created
    # It needs a dummy config for `terraform init` to pass
    provider "kubernetes" {
      alias = "primary"
      host                   = "https://dummy-host-primary"
      cluster_ca_certificate = "dummy-ca-primary"
      token                  = "dummy-token-primary"
    }

    # Configure the Kubernetes provider for the secondary EKS cluster
    provider "kubernetes" {
      alias = "secondary"
      host                   = "https://dummy-host-secondary"
      cluster_ca_certificate = "dummy-ca-secondary"
      token                  = "dummy-token-secondary"
    }

    # Configure the Helm provider for the primary EKS cluster
    provider "helm" {
      alias = "primary"
      kubernetes {
        host                   = "https://dummy-helm-host-primary"
        cluster_ca_certificate = "dummy-helm-ca-primary"
        token                  = "dummy-helm-token-primary"
      }
    }

    # Configure the Helm provider for the secondary EKS cluster
    provider "helm" {
      alias = "secondary"
      kubernetes {
        host                   = "https://dummy-helm-host-secondary"
        cluster_ca_certificate = "dummy-helm-ca-secondary"
        token                  = "dummy-helm-token-secondary"
      }
    }

# data "aws_eks_cluster_auth" "main" {
#   name     = aws_eks_cluster.main.name
# }

