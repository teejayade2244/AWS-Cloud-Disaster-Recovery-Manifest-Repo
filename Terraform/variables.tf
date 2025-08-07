# --- Global Variables for Multi-Region Deployment ---
# Primary AWS Region
variable "primary_region" {
  description = "The AWS region for the primary deployment (e.g., eu-west-2)."
  type        = string
}

# Secondary AWS Region (for Disaster Recovery)
variable "secondary_region" {
  description = "The AWS region for the secondary (DR) deployment (e.g., us-east-1)."
  type        = string
}

# --- Primary Region Networking Variables ---
variable "primary_vpc_cidr" {
  description = "CIDR block for the VPC in the primary region."
  type        = string
}

variable "primary_public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets in the primary region (e.g., [\"10.0.1.0/24\", \"10.0.2.0/24\"])."
  type        = list(string)
}

variable "primary_private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets in the primary region (e.g., [\"10.0.10.0/24\", \"10.0.11.0/24\"])."
  type        = list(string)
}

# --- Secondary Region Networking Variables ---
variable "secondary_vpc_cidr" {
  description = "CIDR block for the VPC in the secondary region."
  type        = string
}

variable "secondary_public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets in the secondary region (e.g., [\"10.1.1.0/24\", \"10.1.2.0/24\"])."
  type        = list(string)
}

variable "secondary_private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets in the secondary region (e.g., [\"10.1.10.0/24\", \"10.1.11.0/24\"])."
  type        = list(string)
}

# # --- EKS Cluster Variables (will be used in compute module) ---
variable "cluster_name_prefix" {
  description = "Prefix for the EKS cluster names (e.g., 'aura-flow')."
  type        = string
  default     = "aura-flow"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS clusters."
  type        = string
  default     = "1.28" # Or your preferred version
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes."
  type        = string
  default     = "t3.medium" # Adjust based on your needs
}

variable "node_group_desired_size" {
  description = "Desired number of worker nodes in the EKS node group."
  type        = number
  default     = 2 # For warm standby, primary might be higher, secondary lower
}

variable "node_group_max_size" {
  description = "Maximum number of worker nodes in the EKS node group."
  type        = number
  default     = 3
}

variable "node_group_min_size" {
  description = "Minimum number of worker nodes in the EKS node group."
  type        = number
  default     = 1
}

# # --- RDS Database Variables (will be used in rds module) ---
# variable "db_instance_type" {
#   description = "RDS DB instance type (e.g., db.t3.micro)."
#   type        = string
#   default     = "db.t3.micro"
# }

# variable "db_allocated_storage" {
#   description = "Allocated storage for the database in GB."
#   type        = number
#   default     = 20
# }

# variable "db_engine_version" {
#   description = "PostgreSQL engine version."
#   type        = string
#   default     = "14.7" 
# }

# variable "db_username" {
#   description = "Master username for the database."
#   type        = string
#   sensitive   = true # Mark as sensitive to prevent logging
# }

# variable "db_password" {
#   description = "Master password for the database."
#   type        = string
#   sensitive   = true # Mark as sensitive
# }
