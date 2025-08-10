# providers.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Primary region provider
provider "aws" {
  alias  = "primary"
  region = var.primary_region
}

# Secondary region provider
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}

provider "tls" {
  alias = "primary"
}

provider "tls" {
  alias = "secondary"
}