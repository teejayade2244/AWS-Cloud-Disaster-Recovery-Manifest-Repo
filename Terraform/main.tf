terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
# Generate a secure password that meets RDS requirements
resource "random_password" "shared_db_master_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}|;:,.<>?"
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}

# Primary Infrastructure
module "primary_networking" {
  source              = "./modules/aws-region-base/networking"
  region              = var.primary_region
  vpc_cidr            = var.primary_vpc_cidr
  public_subnet_cidrs = var.primary_public_subnet_cidrs
  private_subnet_cidrs = var.primary_private_subnet_cidrs
  environment_tag     = "Production"
  providers = {
    aws = aws.primary
  }
}

# Secondary Infrastructure
module "secondary_networking" {
  source              = "./modules/aws-region-base/networking"
  region              = var.secondary_region
  vpc_cidr            = var.secondary_vpc_cidr
  public_subnet_cidrs = var.secondary_public_subnet_cidrs
  private_subnet_cidrs = var.secondary_private_subnet_cidrs
  environment_tag     = "DisasterRecovery"
  providers = {
    aws = aws.secondary
  }
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

