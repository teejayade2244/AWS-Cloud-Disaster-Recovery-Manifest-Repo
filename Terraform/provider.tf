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
    # helm = {
    #   source = "hashicorp/helm"
    #   version = "2.12.1" 
    # }
    tls = { # TLS provider is still needed for OIDC thumbprint
      source  = "hashicorp/tls"
      version = "~> 4.0" # Use a compatible version
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


