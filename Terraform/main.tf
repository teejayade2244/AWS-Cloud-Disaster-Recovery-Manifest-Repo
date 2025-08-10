resource "random_password" "shared_db_master_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}|;:,.<>?"
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}

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
  node_group_desired_size = 1
  node_group_max_size   = var.node_group_max_size
  node_group_min_size   = 1
  allowed_inbound_cidrs = local.secondary_eks_allowed_cidrs

  providers = {
    aws = aws.secondary
    tls = tls.secondary
  }

  depends_on = [
    module.vpc_peering
  ]
}
# Primary Database
module "primary_database" {
  source = "./modules/aws-region-base/rds"
  region              = var.primary_region
  environment_tag     = "Production"
  vpc_id              = module.primary_networking.vpc_id
  private_subnet_ids  = module.primary_networking.private_subnet_ids
  replica_region      = var.secondary_region

  db_name                  = var.primary_db_name
  db_instance_class        = var.primary_db_instance_class
  db_engine                = var.primary_db_engine
  db_engine_version        = var.primary_db_engine_version
  db_allocated_storage     = var.primary_db_allocated_storage
  db_master_username       = var.primary_db_master_username
  db_master_password       = random_password.shared_db_master_password.result
  db_port                  = var.primary_db_port
  db_skip_final_snapshot   = var.primary_db_skip_final_snapshot
  db_backup_retention_period = var.primary_db_backup_retention_period
  db_deletion_protection   = var.primary_db_deletion_protection
  db_multi_az              = var.primary_db_multi_az

  is_read_replica       = false
  source_db_instance_arn = null

  providers = {
    aws = aws.primary
  }
}

# Secondary Database (Read Replica)
module "secondary_database" {
  source = "./modules/aws-region-base/rds"
  region              = var.secondary_region
  environment_tag     = "DisasterRecovery"
  vpc_id              = module.secondary_networking.vpc_id
  private_subnet_ids  = module.secondary_networking.private_subnet_ids
  replica_region      = null # No replication from replica

  db_name                  = var.secondary_db_name
  db_instance_class        = var.secondary_db_instance_class
  db_engine                = var.primary_db_engine # Use primary's engine
  db_engine_version        = var.primary_db_engine_version # Use primary's version
  db_allocated_storage     = var.secondary_db_allocated_storage
  db_master_username       = var.primary_db_master_username # Use primary's username
  db_master_password       = random_password.shared_db_master_password.result
  db_port                  = var.primary_db_port # Use primary's port
  db_skip_final_snapshot   = var.secondary_db_skip_final_snapshot
  db_backup_retention_period = var.secondary_db_backup_retention_period
  db_deletion_protection   = var.secondary_db_deletion_protection
  db_multi_az              = var.secondary_db_multi_az

  is_read_replica       = true
  source_db_instance_arn = module.primary_database.db_instance_arn

  providers = {
    aws = aws.secondary
  }
}


module "primary_ecr_repos" {
  source = "./modules/aws-region-base/ecr"
  project_name    = var.project_name
  environment_tag = "Production"
  region_suffix   = var.primary_region
  application_names = var.application_names
  image_tag_mutability = "IMMUTABLE"
  scan_on_push         = true

  providers = {
    aws = aws.primary
  }
}

# Call the ECR module for the secondary (DR) region
module "secondary_ecr_repos" {
  source = "./modules/aws-region-base/ecr"
  project_name    = var.project_name
  environment_tag = "DisasterRecovery"
  region_suffix   = var.secondary_region
  application_names = var.application_names

  providers = {
    aws = aws.secondary
  }
}
