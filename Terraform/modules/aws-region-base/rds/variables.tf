# Variables for the Database Module

variable "region" {
  description = "The AWS region where the database will be deployed."
  type        = string
}

variable "environment_tag" {
  description = "Environment tag for resources (e.g., 'Production', 'DisasterRecovery')."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the database will be deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "A list of private subnet IDs for the database."
  type        = list(string)
}

variable "db_name" {
  description = "The name of the database to create."
  type        = string
  # db_name, username, password, engine, engine_version are inherited from source if it's a read replica.
  # They are still needed for a standalone instance.
}

variable "db_instance_class" {
  description = "The instance type of the database (e.g., db.t3.micro)."
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
  description = "The allocated storage in GB."
  type        = number
}

variable "db_master_username" {
  description = "The master username for the database."
  type        = string
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

# New variable for cross-region read replica configuration
variable "source_db_instance_arn" {
  description = "The ARN of the source DB instance if creating a read replica. Set to null for a standalone instance."
  type        = string
  default     = null # Default to null for a standalone instance
}
