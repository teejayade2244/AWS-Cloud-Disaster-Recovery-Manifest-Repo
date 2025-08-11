# main.tf for the RDS module (./modules/aws-region-base/rds/)

# Declare the required AWS provider for this module
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Data source to get information about the VPC using the provided vpc_id
data "aws_vpc" "current" {
  id = var.vpc_id
}

resource "aws_db_subnet_group" "default" {
  # Convert environment_tag to lowercase for valid AWS naming
  name       = "${lower(var.environment_tag)}-${var.region}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Environment = var.environment_tag
    Region      = var.region
  }
}

resource "aws_security_group" "rds_sg" {
  # Convert environment_tag to lowercase for valid AWS naming
  name        = "${lower(var.environment_tag)}-${var.region}-rds-sg"
  description = "Allow inbound traffic to RDS instance from within its VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    # Allow traffic only from within the VPC's CIDR block
    cidr_blocks = [data.aws_vpc.current.cidr_block]
    description = "Allow database traffic from within VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment_tag
    Region      = var.region
  }
}

# Primary DB Instance (if not a read replica)
resource "aws_db_instance" "main" {
  count = var.is_read_replica ? 0 : 1 # Only create if it's not a read replica

  # Custom identifier for the DB instance
  identifier             = "${lower(var.environment_tag)}-${var.region}-${replace(var.db_name, "_", "-")}"

  allocated_storage      = var.db_allocated_storage
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  db_name                = var.db_name # The actual database name inside the instance, can have underscores
  username               = var.db_master_username
  password               = var.db_master_password # Directly use the provided password variable
  port                   = var.db_port
  multi_az               = var.db_multi_az
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = var.db_skip_final_snapshot
  backup_retention_period = var.db_backup_retention_period
  deletion_protection    = var.db_deletion_protection
  publicly_accessible    = false

  # REQUIRED when skip_final_snapshot is false
  final_snapshot_identifier = "${lower(var.environment_tag)}-${var.region}-${replace(var.db_name, "_", "-")}-final-snapshot"

  tags = {
    Name        = "${var.environment_tag}-${var.region}-rds-instance"
    Environment = var.environment_tag
    Region      = var.region
  }
}

# Read Replica DB Instance (if it is a read replica)
resource "aws_db_instance" "read_replica" {
  count = var.is_read_replica ? 1 : 0 # Only create if it is a read replica

  # Custom identifier for the read replica
  identifier             = "${lower(var.environment_tag)}-${var.region}-${replace(var.db_name, "_", "-")}-replica"

  replicate_source_db    = var.source_db_instance_arn
  instance_class         = var.db_instance_class
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = var.db_skip_final_snapshot
  backup_retention_period = var.db_backup_retention_period
  deletion_protection    = var.db_deletion_protection
  publicly_accessible    = false
  # username, password, engine, engine_version, allocated_storage, port are inherited from source DB.

  # REQUIRED when skip_final_snapshot is false
  final_snapshot_identifier = "${lower(var.environment_tag)}-${var.region}-${replace(var.db_name, "_", "-")}-replica-final-snapshot"

  tags = {
    Name        = "${var.environment_tag}-${var.region}-rds-read-replica"
    Environment = var.environment_tag
    Region      = var.region
  }
}

# Secret Manager for DB Credentials (only created for the primary database)
resource "aws_secretsmanager_secret" "db_credentials" {
  count = var.is_read_replica ? 0 : 1 # Only create this secret for the primary DB

  # Convert environment_tag to lowercase for valid AWS naming
  name_prefix = "${lower(var.environment_tag)}/${var.region}/db-credentials"
  description = "Database credentials for RDS instance in ${var.region} ${var.environment_tag}"

  tags = {
    Environment = var.environment_tag
    Region      = var.region
  }

  # --- CRITICAL: Add replication to the secondary region ---
  # This block is only processed if count is 1 (i.e., for the primary secret)
  dynamic "replica" {
    for_each = var.is_read_replica ? [] : [var.secondary_region_to_replicate_to] # Only if not a replica
    content {
      region = replica.value
    }
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  count = var.is_read_replica ? 0 : 1 # Only create this secret version for the primary DB

  secret_id = aws_secretsmanager_secret.db_credentials[0].id
  secret_string = jsonencode({
    db_name  = var.db_name
    engine   = var.db_engine
    # Dynamically set host based on whether it's the main instance or a read replica
    # This host will be for the primary in the secret. Applications will connect to their local endpoint.
    host     = aws_db_instance.main[0].address
    password = var.db_master_password # Store the explicitly provided password
    port     = var.db_port
    username = var.db_master_username
  })
}
