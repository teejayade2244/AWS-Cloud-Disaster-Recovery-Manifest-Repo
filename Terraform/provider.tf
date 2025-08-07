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
      source  = "hashicorp/helm"
      version = "2.12.1" # Using v2.x which supports the block syntax
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

provider "kubernetes" {
  alias                  = "primary"
  host                   = "https://dummy-host-primary"
  cluster_ca_certificate = "dummy-ca-primary"
  token                  = "dummy-token-primary"
}

provider "kubernetes" {
  alias                  = "secondary"
  host                   = "https://dummy-host-secondary"
  cluster_ca_certificate = "dummy-ca-secondary"
  token                  = "dummy-token-secondary"
}

# Correct Helm provider configuration for v2.x
provider "helm" {
  alias = "primary"
  kubernetes {
    host                   = "https://dummy-helm-host-primary"
    cluster_ca_certificate = "dummy-helm-ca-primary"
    token                  = "dummy-helm-token-primary"
  }
}

provider "helm" {
  alias = "secondary"
  kubernetes {
    host                   = "https://dummy-helm-host-secondary"
    cluster_ca_certificate = "dummy-helm-ca-secondary"
    token                  = "dummy-helm-token-secondary"
  }
}