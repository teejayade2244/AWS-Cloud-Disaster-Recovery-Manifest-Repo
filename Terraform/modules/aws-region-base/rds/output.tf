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
  value       = var.is_read_replica ? aws_db_instance.read_replica[0].arn : aws_db_instance.main[0].arn
}

output "db_secret_arn" {
  description = "The ARN of the Secrets Manager secret storing DB credentials."
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_secret_name" {
  description = "The name of the Secrets Manager secret storing DB credentials."
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "db_master_username" {
  description = "The master username for the database."
  value       = var.db_master_username
  sensitive   = true
}

output "db_replica_secret_arn" {
  description = "The ARN of the replicated secret in the secondary region (if applicable)"
  value       = var.replica_region != null ? "${replace(aws_secretsmanager_secret.db_credentials.arn, var.region, var.replica_region)}" : null
}