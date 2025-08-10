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
  description = "The ARN of the Secrets Manager secret storing DB credentials."
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_master_username" {
  description = "The master username for the database."
  value       = var.db_master_username
  sensitive   = false 
}

# output "db_master_password_sm" {
#   description = "The master password stored in Secrets Manager (sensitive)."
#   value       = local.actual_db_password # Referencing the local that holds the actual password
#   sensitive   = true # Mark as sensitive to prevent display in CLI output
# }

output "db_endpoint" {
  description = "The full endpoint of the RDS instance, including port."
  value = var.is_read_replica ? aws_db_instance.read_replica[0].endpoint : aws_db_instance.main[0].endpoint
}
