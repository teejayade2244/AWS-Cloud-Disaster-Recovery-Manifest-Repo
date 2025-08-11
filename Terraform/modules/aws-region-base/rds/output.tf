# Outputs for the Database Module

output "db_instance_endpoint" {
  description = "The connection endpoint of the RDS instance."
  value       = var.is_read_replica ? aws_db_instance.read_replica[0].address : aws_db_instance.main[0].address
}

output "db_instance_port" {
  description = "The port of the RDS instance."
  value       = var.is_read_replica ? aws_db_instance.read_replica[0].port : aws_db_instance.main[0].port
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance."
  value  = var.is_read_replica ? aws_db_instance.read_replica[0].arn : aws_db_instance.main[0].arn
}

output "db_secret_arn" {
  description = "The ARN of the Secrets Manager secret storing DB credentials (only for primary)."
  value       = var.is_read_replica ? null : aws_secretsmanager_secret.db_credentials[0].arn
}

output "db_secret_name" {
  description = "The name of the Secrets Manager secret storing DB credentials (only for primary)."
  value       = var.is_read_replica ? null : aws_secretsmanager_secret.db_credentials[0].name
}

output "db_master_username" {
  description = "The master username for the database."
  value       = var.db_master_username
  sensitive   = false 
}

output "db_endpoint" {
  description = "The full endpoint of the RDS instance, including port."
  value = var.is_read_replica ? aws_db_instance.read_replica[0].endpoint : aws_db_instance.main[0].endpoint
}
