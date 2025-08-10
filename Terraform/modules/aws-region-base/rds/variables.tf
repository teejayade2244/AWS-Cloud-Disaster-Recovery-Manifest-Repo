variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment_tag" {
  description = "Environment tag"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_instance_class" {
  description = "DB instance class"
  type        = string
}

variable "db_engine" {
  description = "Database engine"
  type        = string
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
}

variable "db_master_username" {
  description = "Master username"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot"
  type        = bool
  default     = false
}

variable "db_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "db_multi_az" {
  description = "Enable Multi-AZ"
  type        = bool
  default     = false
}

variable "source_db_instance_arn" {
  description = "Source DB ARN for replicas"
  type        = string
  default     = null
}

variable "is_read_replica" {
  description = "Is this a read replica"
  type        = bool
  default     = false
}