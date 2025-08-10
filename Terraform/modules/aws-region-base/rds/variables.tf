# variables.tf for the RDS module (./modules/aws-region-base/rds/)

variable "vpc_id" {
  description = "The ID of the VPC where the database will be deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "A list of private subnet IDs for the database subnet group."
  type        = list(string)
}

variable "region" {
  description = "The AWS region where the database is being deployed."
  type        = string
}

variable "environment_tag" {
  description = "The environment tag (e.g., Production, Development) for resources."
  type        = string
}

variable "db_name" {
  description = "The name of the database to create inside the DB instance."
  type        = string
}

variable "db_instance_class" {
  description = "The instance type of the RDS instance (e.g., db.t3.micro)."
  type        = string
}

variable "db_engine" {
  description = "The database engine to use (e.g., postgres, mysql)."
  type        = string
}

variable "db_engine_version" {
  description = "The version of the database engine."
  type        = string
}

variable "db_allocated_storage" {
  description = "The allocated storage in GB for the database."
  type        = number
}

variable "db_master_username" {
  description = "The master username for the database."
  type        = string
}

variable "db_master_password" {
  description = "The master password for the database. Must be printable ASCII characters, excluding /, @, \", and space."
  type        = string
  sensitive   = true # Mark as sensitive to prevent showing in plan output
}

variable "db_port" {
  description = "The port on which the database accepts connections."
  type        = number
}

variable "db_skip_final_snapshot" {
  description = "Set to true to skip the final DB snapshot when deleting the DB instance."
  type        = bool
}

variable "db_backup_retention_period" {
  description = "The days to retain backups. Must be between 0 and 35."
  type        = number
}

variable "db_deletion_protection" {
  description = "Set to true to enable deletion protection for the DB instance."
  type        = bool
}

variable "db_multi_az" {
  description = "Specifies if the DB instance is Multi-AZ."
  type        = bool
}

variable "is_read_replica" {
  description = "Set to true if this RDS instance should be a read replica."
  type        = bool
  default     = false
}

variable "source_db_instance_arn" {
  description = "The ARN of the source DB instance for a read replica."
  type        = string
  default     = null # Only required if is_read_replica is true
}

# --- NEW: Secondary region for Secrets Manager replication ---
variable "secondary_region_to_replicate_to" {
  description = "The region to replicate the primary secret to. Only relevant for primary DB secrets."
  type        = string
  default     = null # Only applicable for the primary secret
}
