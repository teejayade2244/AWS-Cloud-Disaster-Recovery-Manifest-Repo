# main.tf - Infrastructure only

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

module "vpc_peering" {
  source = "./modules/aws-region-base/peering"

  primary_region             = var.primary_region
  secondary_region           = var.secondary_region
  primary_vpc_id             = module.primary_networking.vpc_id
  primary_vpc_cidr           = var.primary_vpc_cidr
  primary_private_subnet_ids = module.primary_networking.private_subnet_ids
  primary_public_subnet_ids  = module.primary_networking.public_subnet_ids
  secondary_vpc_id           = module.secondary_networking.vpc_id
  secondary_vpc_cidr         = var.secondary_vpc_cidr
  secondary_private_subnet_ids = module.secondary_networking.private_subnet_ids
  secondary_public_subnet_ids  = module.secondary_networking.public_subnet_ids
  primary_public_route_table_id   = module.primary_networking.public_route_table_id
  primary_private_route_table_ids = module.primary_networking.private_route_table_ids
  secondary_public_route_table_id = module.secondary_networking.public_route_table_id
  secondary_private_route_table_ids = module.secondary_networking.private_route_table_ids

  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
  }

  depends_on = [
    module.primary_networking,
    module.secondary_networking
  ]
}

locals {
  terraform_server_private_ip_cidr = "10.0.2.111/32"
  primary_eks_allowed_cidrs = [
    var.primary_vpc_cidr,          
    var.secondary_vpc_cidr,        
    local.terraform_server_private_ip_cidr 
  ]
  secondary_eks_allowed_cidrs = [
    var.secondary_vpc_cidr,       
    var.primary_vpc_cidr,         
    local.terraform_server_private_ip_cidr 
  ]
}

# Create EKS clusters
module "primary_eks" {
  source = "./modules/aws-region-base/eks"

  region                = var.primary_region
  environment_tag       = "Production"
  vpc_id                = module.primary_networking.vpc_id
  private_subnet_ids    = module.primary_networking.private_subnet_ids
  public_subnet_ids     = module.primary_networking.public_subnet_ids
  cluster_name          = "${var.cluster_name_prefix}-${var.primary_region}"
  kubernetes_version    = var.kubernetes_version
  node_instance_type    = var.node_instance_type
  node_group_desired_size = var.node_group_desired_size 
  node_group_max_size   = var.node_group_max_size
  node_group_min_size   = var.node_group_min_size
  allowed_inbound_cidrs = local.primary_eks_allowed_cidrs

  providers = {
    aws = aws.primary
    tls = tls.primary
  }

  depends_on = [
    module.vpc_peering
  ]
}

module "secondary_eks" {
  source = "./modules/aws-region-base/eks"

  region                = var.secondary_region
  environment_tag       = "DisasterRecovery"
  vpc_id                = module.secondary_networking.vpc_id
  private_subnet_ids    = module.secondary_networking.private_subnet_ids
  public_subnet_ids     = module.secondary_networking.public_subnet_ids
  cluster_name          = "${var.cluster_name_prefix}-${var.secondary_region}"
  kubernetes_version    = var.kubernetes_version
  node_instance_type    = var.node_instance_type
  node_group_desired_size = 0
  node_group_max_size   = var.node_group_max_size
  node_group_min_size   = 0
  allowed_inbound_cidrs = local.secondary_eks_allowed_cidrs

  providers = {
    aws = aws.secondary
    tls = tls.secondary
  }

  depends_on = [
    module.vpc_peering
  ]
}

