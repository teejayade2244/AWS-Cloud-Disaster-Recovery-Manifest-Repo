terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Conditionally generate a random password if not explicitly provided
resource "random_password" "db_master_password" {
  length           = 16
  special          = true
  override_special = "!@#$%^&*"
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}


# Determine the actual password to use: either the provided one or the randomly generated one
locals {
  # We need to use [0] because 'count' is set, even if count = 1.
  actual_db_password = var.db_master_password != null ? var.db_master_password : random_password.db_master_password[0].result
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

  allocated_storage      = var.db_allocated_storage
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_master_username
  password               = local.actual_db_password # Use the determined password
  port                   = var.db_port
  multi_az               = var.db_multi_az
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = var.db_skip_final_snapshot
  backup_retention_period = var.db_backup_retention_period
  deletion_protection    = var.db_deletion_protection
  publicly_accessible    = false

  tags = {
    Name        = "${var.environment_tag}-${var.region}-rds-instance"
    Environment = var.environment_tag
    Region      = var.region
  }
}

# Read Replica DB Instance (if it is a read replica)
resource "aws_db_instance" "read_replica" {
  count = var.is_read_replica ? 1 : 0 # Only create if it is a read replica

  replicate_source_db    = var.source_db_instance_arn
  instance_class         = var.db_instance_class
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = var.db_skip_final_snapshot
  backup_retention_period = var.db_backup_retention_period
  deletion_protection    = var.db_deletion_protection
  publicly_accessible    = false
  # REMOVED: username, password, engine, engine_version, allocated_storage, port
  # These are inherited from the source DB instance when replicate_source_db is used.

  tags = {
    Name        = "${var.environment_tag}-${var.region}-rds-read-replica"
    Environment = var.environment_tag
    Region      = var.region
  }
}

resource "aws_secretsmanager_secret" "db_credentials" {
  # Convert environment_tag to lowercase for valid AWS naming
  name_prefix = "${lower(var.environment_tag)}/${var.region}/db-credentials-"
  description = "Database credentials for RDS instance in ${var.region} ${var.environment_tag}"

  tags = {
    Environment = var.environment_tag
    Region      = var.region
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    db_name  = var.db_name
    engine   = var.db_engine
    # Dynamically set host based on whether it's the main instance or a read replica
    host     = var.is_read_replica ? aws_db_instance.read_replica[0].address : aws_db_instance.main[0].address
    password = local.actual_db_password # Store the actual determined password
    port     = var.db_port
    username = var.db_master_username
  })
}
