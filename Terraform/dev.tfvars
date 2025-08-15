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
primary_db_engine_version      = "14.17"
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
secondary_db_engine_version      = "14.17"
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
github_organization = "teejayade2244" 
github_repository  = "Cloud-Disaster-Recovery-Demo-App-React-Frontend-and-Python-Backend" 

domain_name        = "coreservetest.co.uk" 
app_subdomain_name = "app"          

# --- Health Check Configuration ---
health_check_port     = 80      
health_check_protocol = "HTTP"  
health_check_path     = "/"     

# --- SNS Notification Topic Details ---
sns_topic_name     = "aura-flow-health-alerts"          
notification_email = "T.a.adebunmi@wlv.ac.uk"   

# --- Optional: www CNAME ---
create_www_cname = false

# --- DR Database and Secret Details (for Lambda) ---
dr_db_replica_id               = "db-5IGUXPWA2R4CXAV6J7MSG2K4GY" 
dr_db_credentials_secret_name  = "disasterrecovery-us-east-1-replica-db-credentials"  
notification_topic_arn         = "arn:aws:sns:us-east-1:899411341244:aura-flow-route53-health-notifications" 
