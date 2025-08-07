module "primary_networking" {
  source = "./modules/aws-region-base/networking" 
  region              = var.primary_region
  vpc_cidr            = var.primary_vpc_cidr
  public_subnet_cidrs = var.primary_public_subnet_cidrs
  private_subnet_cidrs = var.primary_private_subnet_cidrs
  environment_tag     = "Production"
  providers = {
    aws = aws.primary
  }
}

module "secondary_networking" {
  source = "./modules/aws-region-base/networking" 
  region              = var.secondary_region
  vpc_cidr            = var.secondary_vpc_cidr
  public_subnet_cidrs = var.secondary_public_subnet_cidrs
  private_subnet_cidrs = var.secondary_private_subnet_cidrs
  environment_tag     = "DisasterRecovery"

  providers = {
    aws = aws.secondary
  }
}
