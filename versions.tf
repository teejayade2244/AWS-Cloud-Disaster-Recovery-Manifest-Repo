# --- Terraform Version and Required Providers ---

terraform {
  required_version = ">= 1.0.0" # Specify a minimum required Terraform version

  # Configure the Terraform backend for state storage
  # This bucket should be created manually once before running terraform init

  backend "s3" {
    bucket         = "terraform-state-auraflow-app"
    key            = "terraform.tfstate"
    region         = "eu-west-2"
    use_lockfile   = true
    encrypt        = true
  }



  # Declare all required providers and their versions
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use a compatible version for AWS
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23" # Use a compatible version for Kubernetes
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11" # Use a compatible version for Helm
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0" # Use a compatible version for TLS
    }
  }
}
