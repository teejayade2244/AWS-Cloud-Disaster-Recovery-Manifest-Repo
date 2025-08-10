terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_vpc" "current" {
  id = var.vpc_id
}

data "aws_caller_identity" "current" {}

locals {
  actual_db_password = var.db_master_password != null ? var.db_master_password : random_password.db_master_password[0].result
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

resource "aws_db_instance" "main" {
  count = var.is_read_replica ? 0 : 1

  allocated_storage      = var.db_allocated_storage
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_master_username
  password               = local.actual_db_password
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

resource "aws_db_instance" "read_replica" {
  count = var.is_read_replica ? 1 : 0

  replicate_source_db    = var.source_db_instance_arn
  instance_class         = var.db_instance_class
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = var.db_skip_final_snapshot
  backup_retention_period = var.db_backup_retention_period
  deletion_protection    = var.db_deletion_protection
  publicly_accessible    = false

  tags = {
    Name        = "${var.environment_tag}-${var.region}-rds-read-replica"
    Environment = var.environment_tag
    Region      = var.region
  }
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name_prefix = "${lower(var.environment_tag)}/${var.region}/db-credentials-"
  description = "Database credentials for RDS instance in ${var.region} ${var.environment_tag}"

  dynamic "replica" {
    for_each = var.replica_region != null ? [1] : []
    content {
      region = var.replica_region
    }
  }

  tags = {
    Environment = var.environment_tag
    Region      = var.region
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    db_name     = var.db_name
    engine      = var.db_engine
    host        = var.is_read_replica ? aws_db_instance.read_replica[0].address : aws_db_instance.main[0].address
    password    = local.actual_db_password
    port        = var.db_port
    username    = var.db_master_username
    is_primary  = !var.is_read_replica
    primary_region = var.region
    replica_regions = var.replica_region != null ? [var.replica_region] : []
  })
}

resource "aws_secretsmanager_secret_policy" "db_credentials_policy" {
  secret_arn = aws_secretsmanager_secret.db_credentials.arn
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = "*"
      }
    ]
  })
}