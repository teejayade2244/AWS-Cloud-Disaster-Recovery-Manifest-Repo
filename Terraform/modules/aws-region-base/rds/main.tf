terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "random_password" "db_master_password" {
  length           = 16
  special          = true
  override_special = "!@#$%^&*"
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}

resource "aws_security_group" "db_sg" {
  name        = "${lower(var.environment_tag)}-${lower(var.region)}-db-sg"
  description = "Security group for RDS database"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment_tag}-${var.region}-db-sg"
    Environment = var.environment_tag
  }
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

resource "aws_db_subnet_group" "main" {
  name        = "${lower(var.environment_tag)}-${lower(var.region)}-db-subnet-group"
  subnet_ids  = var.private_subnet_ids
  description = "DB Subnet Group for RDS instance"

  tags = {
    Name        = "${var.environment_tag}-${var.region}-db-subnet-group"
    Environment = var.environment_tag
  }
}

resource "aws_db_instance" "main" {
  count                  = var.is_read_replica ? 0 : 1
  identifier             = "${lower(var.environment_tag)}-${lower(var.region)}-db-instance"
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
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
}

resource "aws_db_instance" "read_replica" {
  count                  = var.is_read_replica ? 1 : 0
  identifier             = "${lower(var.environment_tag)}-${lower(var.region)}-db-replica"
  instance_class         = var.db_instance_class
  replicate_source_db    = var.source_db_instance_arn
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false
  multi_az               = var.db_multi_az
  skip_final_snapshot    = var.db_skip_final_snapshot
  backup_retention_period = var.db_backup_retention_period
  deletion_protection    = var.db_deletion_protection

  tags = {
    Name        = "${var.environment_tag}-${var.region}-db-replica"
    Environment = var.environment_tag
  }
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.environment_tag}/${var.region}/db-credentials"
  description = "RDS ${var.db_engine} credentials for ${var.environment_tag} in ${var.region}"

  tags = {
    Environment = var.environment_tag
    Region      = var.region
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.db_master_password.result
    db_name  = var.db_name
    engine   = var.db_engine
    host     = var.is_read_replica ? aws_db_instance.read_replica[0].address : aws_db_instance.main[0].address
    port     = var.db_port
  })
}
