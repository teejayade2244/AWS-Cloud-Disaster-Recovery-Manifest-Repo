# --- SOLUTION 2: Add a boolean variable to control instance type ---

# Add this to your variables.tf file:
variable "create_read_replica" {
  description = "Whether to create a read replica (true) or standalone instance (false)"
  type        = bool
  default     = false
}

# Then modify your resource blocks:

# Primary/Standalone RDS Instance
resource "aws_db_instance" "main" {
  provider = aws
  count    = var.create_read_replica ? 0 : 1
  
  identifier             = "${lower(var.environment_tag)}-${lower(var.region)}-db-instance"
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  storage_type           = "gp2"
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_name                = var.db_name
  username               = var.db_master_username
  password               = random_password.db_master_password.result
  port                   = var.db_port
  multi_az               = var.db_multi_az
  skip_final_snapshot    = var.db_skip_final_snapshot
  backup_retention_period = var.db_backup_retention_period
  deletion_protection    = var.db_deletion_protection
  publicly_accessible    = false

  tags = {
    Name        = "${var.environment_tag}-${var.region}-db-instance"
    Environment = var.environment_tag
  }
  depends_on = [random_password.db_master_password]
}

# Cross-Region Read Replica RDS Instance
resource "aws_db_instance" "read_replica" {
  provider = aws
  count    = var.create_read_replica ? 1 : 0

  identifier              = "${lower(var.environment_tag)}-${lower(var.region)}-db-instance-replica"
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  storage_type            = "gp2"
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  publicly_accessible     = false
  multi_az                = var.db_multi_az 
  skip_final_snapshot     = var.db_skip_final_snapshot
  backup_retention_period = var.db_backup_retention_period
  deletion_protection     = var.db_deletion_protection

  replicate_source_db = var.source_db_instance_arn

  tags = {
    Name        = "${var.environment_tag}-${var.region}-db-instance-replica"
    Environment = var.environment_tag
  }
  depends_on = [random_password.db_master_password]
}

# Update the secrets manager to handle the new structure:
resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  provider = aws
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.db_master_password.result
    db_name  = var.db_name
    engine   = var.db_engine
    # Dynamically select host based on which instance type is created
    host     = var.create_read_replica ? aws_db_instance.read_replica[0].address : aws_db_instance.main[0].address
    port     = var.db_port
  })
  depends_on = [
    aws_db_instance.main,
    aws_db_instance.read_replica,
    random_password.db_master_password
  ]
}