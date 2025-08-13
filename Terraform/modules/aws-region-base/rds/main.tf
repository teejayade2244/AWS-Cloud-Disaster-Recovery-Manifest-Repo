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
  name       = "${lower(var.environment_tag)}-${var.region}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Environment = var.environment_tag
    Region      = var.region
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "${lower(var.environment_tag)}-${var.region}-rds-sg"
  description = "Allow inbound traffic to RDS instance from within its VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.current.cidr_block]
    description = "Allow database traffic from within VPC"
  }

  # Add ingress rule for cross-region VPC access (for read replica)
  dynamic "ingress" {
    for_each = var.cross_region_vpc_cidr != null ? [1] : []
    content {
      from_port   = var.db_port
      to_port     = var.db_port
      protocol    = "tcp"
      cidr_blocks = [var.cross_region_vpc_cidr]
      description = "Allow database traffic from cross-region VPC"
    }
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
  count = var.is_read_replica ? 0 : 1

  identifier             = "${lower(var.environment_tag)}-${var.region}-${replace(var.db_name, "_", "-")}"
  allocated_storage      = var.db_allocated_storage
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_master_username
  password               = var.db_master_password
  port                   = var.db_port
  multi_az               = var.db_multi_az
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = var.db_skip_final_snapshot
  backup_retention_period = var.db_backup_retention_period
  deletion_protection    = var.db_deletion_protection
  publicly_accessible    = false
  final_snapshot_identifier = "${lower(var.environment_tag)}-${var.region}-${replace(var.db_name, "_", "-")}-final-snapshot"

  tags = {
    Name        = "${var.environment_tag}-${var.region}-rds-instance"
    Environment = var.environment_tag
    Region      = var.region
  }
}

# Read Replica DB Instance (if it is a read replica)
resource "aws_db_instance" "read_replica" {
  count = var.is_read_replica ? 1 : 0

  identifier             = "${lower(var.environment_tag)}-${var.region}-${replace(var.db_name, "_", "-")}-replica"
  replicate_source_db    = var.source_db_instance_arn
  instance_class         = var.db_instance_class
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = var.db_skip_final_snapshot
  backup_retention_period = var.db_backup_retention_period
  deletion_protection    = var.db_deletion_protection
  publicly_accessible    = false
  final_snapshot_identifier = "${lower(var.environment_tag)}-${var.region}-${replace(var.db_name, "_", "-")}-replica-final-snapshot"

  tags = {
    Name        = "${var.environment_tag}-${var.region}-rds-read-replica"
    Environment = var.environment_tag
    Region      = var.region
  }
}

# Secret Manager for DB Credentials - PRIMARY DATABASE
resource "aws_secretsmanager_secret" "primary_db_credentials" {
  count = var.is_read_replica ? 0 : 1

  name        = "${lower(var.environment_tag)}-${var.region}-primary-db-credentials" # Add '-primary' to distinguish
  description = "Database credentials for primary RDS instance in ${var.region} ${var.environment_tag}"

  tags = {
    Environment = var.environment_tag
    Region      = var.region
    DatabaseType = "primary"
  }
}

resource "aws_secretsmanager_secret_version" "primary_db_credentials_version" {
  count = var.is_read_replica ? 0 : 1

  secret_id = aws_secretsmanager_secret.primary_db_credentials[0].id
  secret_string = jsonencode({
    db_name  = var.db_name
    engine   = var.db_engine
    host     = aws_db_instance.main[0].address
    password = var.db_master_password
    port     = var.db_port
    username = var.db_master_username
  })
}

# Secret Manager for DB Credentials - READ REPLICA DATABASE
resource "aws_secretsmanager_secret" "replica_db_credentials" {
  count = var.is_read_replica ? 1 : 0

  name        = "${lower(var.environment_tag)}-${var.region}-replica-db-credentials" # Add '-replica' to distinguish
  description = "Database credentials for read replica RDS instance in ${var.region} ${var.environment_tag}"

  tags = {
    Environment = var.environment_tag
    Region      = var.region
    DatabaseType = "replica"
  }
}

resource "aws_secretsmanager_secret_version" "replica_db_credentials_version" {
  count = var.is_read_replica ? 1 : 0

  secret_id = aws_secretsmanager_secret.replica_db_credentials[0].id
  secret_string = jsonencode({
    db_name  = var.db_name
    engine   = var.db_engine
    host     = aws_db_instance.read_replica[0].address  # Points to replica endpoint
    password = var.db_master_password
    port     = var.db_port
    username = var.db_master_username
  })
}