provider "aws" {
  region = var.primary_region
  alias  = "primary" # Alias to distinguish this provider instance
}

provider "aws" {
  region = var.secondary_region
  alias  = "secondary" # Alias to distinguish this provider instance
}

terraform {
  backend "s3" {
    bucket         = "your-unique-s3-bucket-name-for-tfstate"
    key            = "multi-region-dr/terraform.tfstate"
    region         = "eu-west-2" # Store state in your primary region
    encrypt        = true
    dynamodb_table = "terraform-state-locking" # DynamoDB table for state locking
  }
}
