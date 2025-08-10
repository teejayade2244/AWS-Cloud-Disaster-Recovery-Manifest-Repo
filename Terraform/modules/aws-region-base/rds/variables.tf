# variables.tf for the RDS module (./modules/aws-region-base/rds/)

variable "region" {
  description = "The AWS region where the RDS instance will be deployed."
  type        = string
}

variable "environment_tag" {
  description = "Tag for environment (e.g., Production, Development, DisasterRecovery)."
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID to deploy the RDS instance into."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the RDS instance."
  type        = list(string)
}

variable "db_name" {
  description = "The name of the database to create."
  type        = string
}

variable "db_instance_class" {
  description = "The instance type of the database (e.g., db.t3.small)."
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

variable "db_master_password" {
  description = "The master password for the database. If not provided, a random one will be generated."
  type        = string
  default     = null # Make it optional
  sensitive   = true # Mark as sensitive
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
  description = "The days to retain backups for. Must be between 0 and 35."
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
  description = "Set to true if this RDS instance is a read replica."
  type        = bool
  default     = false
}

variable "source_db_instance_arn" {
  description = "The ARN of the source DB instance for a read replica."
  type        = string
  default     = null
}
