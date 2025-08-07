# --- Development Environment Variables ---
# Global Regions
primary_region   = "eu-west-2" # London
secondary_region = "us-east-1" # N. Virginia

# Primary Region (eu-west-2) Networking
primary_vpc_cidr            = "10.0.0.0/16"
primary_public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
primary_private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

# Secondary Region (us-east-1) Networking
secondary_vpc_cidr            = "10.1.0.0/16"
secondary_public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
secondary_private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]

# # EKS Cluster Variables
# cluster_name_prefix   = "aura-flow-dev"
# kubernetes_version    = "1.28"
# node_instance_type    = "t3.medium"
# node_group_desired_size = 2 # Primary: 2 nodes
# node_group_max_size   = 3
# node_group_min_size   = 1

# # RDS Database Variables
# db_instance_type    = "db.t3.micro" # Use a small instance for development
# db_allocated_storage = 20
# db_engine_version   = "14.7"
