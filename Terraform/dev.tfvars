# --- Development Environment Variables ---
# Global Regions
primary_region   = "eu-west-2" # London
secondary_region = "us-east-1" # N. Virginia

# Networking
primary_vpc_cidr            = "10.0.0.0/16"
primary_public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
primary_private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

secondary_vpc_cidr            = "10.1.0.0/16"
secondary_public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
secondary_private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]

# EKS Cluster
cluster_name_prefix   = "aura-flow-dev"
kubernetes_version    = "1.32"
node_instance_type    = "t2.medium"
node_group_desired_size = 2
node_group_max_size   = 3
node_group_min_size   = 1

# Database Configuration
primary_db_name                = "appdb_primary"
primary_db_instance_class      = "db.t3.small"
primary_db_engine              = "postgres"
primary_db_engine_version      = "14.12"
primary_db_allocated_storage   = 20
primary_db_master_username     = "app_user_primary"
primary_db_port                = 5432
primary_db_skip_final_snapshot = false
primary_db_backup_retention_period = 7
primary_db_deletion_protection = true
primary_db_multi_az            = true

secondary_db_name                = "appdb_secondary"
secondary_db_instance_class      = "db.t3.micro"
secondary_db_engine              = "postgres"
secondary_db_engine_version      = "14.12"
secondary_db_allocated_storage   = 20
secondary_db_port                = 5432
secondary_db_skip_final_snapshot = true
secondary_db_backup_retention_period = 1
secondary_db_deletion_protection = false
secondary_db_multi_az            = false

# Application
project_name    = "aura-flow"
application_names = ["backend-api", "frontend-app"]

# GitHub Actions OIDC Role
github_organization = "teejayade2244" # Replace with your GitHub organization name
github_repository  = "Cloud-Disaster-Recovery-Demo-App-React-Frontend-and-Python-Backend" # Replace with your GitHub repository name

