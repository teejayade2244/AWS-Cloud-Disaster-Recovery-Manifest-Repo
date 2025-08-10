# Define the primary AWS region
variable "primary_region" {
  description = "The AWS region for the primary deployment."
  type        = string
  default     = "eu-west-2" # London
}

# Define the secondary AWS region
variable "secondary_region" {
  description = "The AWS region for the secondary (DR) deployment."
  type        = string
  default     = "us-east-1" # N. Virginia (Changed to us-east-1 as it's a common DR pairing)
}

# Define the CIDR block for the primary VPC
variable "primary_vpc_cidr" {
  description = "CIDR block for the VPC in the primary region."
  type        = string
  default     = "10.0.0.0/16"
}

# Define the CIDR block for the secondary VPC
variable "secondary_vpc_cidr" {
  description = "CIDR block for the VPC in the secondary region."
  type        = string
  default     = "10.1.0.0/16" # Ensure this does not overlap with primary_vpc_cidr
}

# Define the public subnet CIDR blocks for primary region
variable "primary_public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets in the primary region."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# Define the private subnet CIDR blocks for primary region
variable "primary_private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets in the primary region."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# Define the public subnet CIDR blocks for secondary region
variable "secondary_public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets in the secondary region."
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

# Define the private subnet CIDR blocks for secondary region
variable "secondary_private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets in the secondary region."
  type        = list(string)
  default     = ["10.1.10.0/24", "10.1.11.0/24"]
}

# EKS Cluster Variables
variable "cluster_name_prefix" {
  description = "Prefix for EKS cluster names."
  type        = string
  default     = "aura-flow-dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS clusters."
  type        = string
  default     = "1.28"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes."
  type        = string
  default     = "t3.medium"
}

variable "node_group_desired_size" {
  description = "Desired number of worker nodes in the EKS node group."
  type        = number
  default     = 2
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

# --- Database Variables for Primary Region ---
variable "primary_db_name" {
  description = "The name of the database for the primary region."
  type        = string
}

variable "primary_db_instance_class" {
  description = "The instance type of the database for the primary region (e.g., db.t3.small)."
  type        = string
}

variable "primary_db_engine" {
  description = "The database engine to use for the primary region (e.g., postgres, mysql)."
  type        = string
}

variable "primary_db_engine_version" {
  description = "The version of the database engine for the primary region."
  type        = string
}

variable "primary_db_allocated_storage" {
  description = "The allocated storage in GB for the primary region database."
  type        = number
}

variable "primary_db_master_username" { # This will be the single source of truth for username
  description = "The master username for the primary region database."
  type        = string
}

variable "primary_db_port" {
  description = "The port on which the primary database accepts connections."
  type        = number
}

variable "primary_db_skip_final_snapshot" {
  description = "Set to true to skip the final DB snapshot when deleting the primary DB instance."
  type        = bool
}

variable "primary_db_backup_retention_period" {
  description = "The days to retain backups for the primary database. Must be between 0 and 35."
  type        = number
}

variable "primary_db_deletion_protection" {
  description = "Set to true to enable deletion protection for the primary DB instance."
  type        = bool
}

variable "primary_db_multi_az" {
  description = "Specifies if the primary DB instance is Multi-AZ."
  type        = bool
}

# --- Database Variables for Secondary Region (mostly for read replica configuration) ---
variable "secondary_db_name" {
  description = "The name of the database for the secondary region (read replica)."
  type        = string
}

variable "secondary_db_instance_class" {
  description = "The instance type of the database for the secondary region (e.g., db.t3.micro)."
  type        = string
}

variable "secondary_db_engine" {
  description = "The database engine to use for the secondary region (read replica)."
  type        = string
}

variable "secondary_db_engine_version" {
  description = "The version of the database engine for the secondary region (read replica)."
  type        = string
}

variable "secondary_db_allocated_storage" {
  description = "The allocated storage in GB for the secondary region database (read replica)."
  type        = number
}

# secondary_db_master_username is REMOVED as it will use primary_db_master_username

variable "secondary_db_port" {
  description = "The port on which the secondary database accepts connections."
  type        = number
}

variable "secondary_db_skip_final_snapshot" {
  description = "Set to true to skip the final DB snapshot when deleting the secondary DB instance."
  type        = bool
}

variable "secondary_db_backup_retention_period" {
  description = "The days to retain backups for the secondary database. Must be between 0 and 35."
  type        = number
}

variable "secondary_db_deletion_protection" {
  description = "Set to true to enable deletion protection for the secondary DB instance."
  type        = bool
}

variable "secondary_db_multi_az" {
  description = "Specifies if the secondary DB instance is Multi-AZ."
  type        = bool
}

variable "project_name" {
  description = "A unique name for your entire project. Used for naming resources."
  type        = string
  # No default here, as it's typically set per environment or via CI/CD
}

variable "application_names" {
  description = "A list of application names for which ECR repositories should be created."
  type        = list(string)
}
