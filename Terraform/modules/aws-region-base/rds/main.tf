# --- Database Module Resources ---
# Explicitly declare the required providers for this module
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = { # Used for generating the password
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Generate a random, strong password for the master user
# This will be generated for both primary and secondary.
# For a read replica, this password is not used for replication,
# but it's available in Secrets Manager if the replica is promoted to a standalone primary later.
resource "random_password" "db_master_password" {
  length           = 16
  special          = true
  override_special = "!@#$%^&*"
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}

# Create a security group for the RDS instance
resource "aws_security_group" "db_sg" {
  provider = aws
  name        = "${var.environment_tag}-${var.region}-db-sg"
  description = "Security group for RDS database"
  vpc_id      = var.vpc_id

  # Inbound rule: Allow traffic from the VPC CIDR on the DB port
  ingress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    # Allows access from anywhere within the VPC
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
    description = "Allow inbound connections from VPC to DB"
  }

  # Outbound rule: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.environment_tag}-${var.region}-db-sg"
    Environment = var.environment_tag
  }
}

# Data source to get the VPC CIDR block for security group ingress
data "aws_vpc" "selected" {
  provider = aws
  id = var.vpc_id
}

# Create a DB Subnet Group for RDS
resource "aws_db_subnet_group" "main" {
  provider = aws
  name        = "${var.environment_tag}-${var.region}-db-subnet-group"
  subnet_ids  = var.private_subnet_ids
  description = "DB Subnet Group for RDS instance"

  tags = {
    Name        = "${var.environment_tag}-${var.region}-db-subnet-group"
    Environment = var.environment_tag
  }
}

# --- Conditional RDS Instance: Primary/Standalone vs. Read Replica ---
# Primary/Standalone RDS Instance
resource "aws_db_instance" "main" {
  # This instance is created only if source_db_instance_arn is NOT provided (i.e., it's a standalone DB)
  provider = aws
  count    = var.source_db_instance_arn == null ? 1 : 0
  identifier             = "${var.environment_tag}-${var.region}-db-instance"
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  storage_type           = "gp2"
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_name                 = var.db_name
  username               = var.db_master_username
  password               = random_password.db_master_password.result # Use generated password
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
  # This instance is created only if source_db_instance_arn IS provided
  provider = aws
  count    = var.source_db_instance_arn != null ? 1 : 0

  identifier              = "${var.environment_tag}-${var.region}-db-instance-replica"
  instance_class          = var.db_instance_class # Can be scaled differently from source
  allocated_storage       = var.db_allocated_storage # Can be scaled differently from source
  storage_type            = "gp2"
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  publicly_accessible     = false
  multi_az                = var.db_multi_az 
  skip_final_snapshot     = var.db_skip_final_snapshot
  backup_retention_period = var.db_backup_retention_period
  deletion_protection     = var.db_deletion_protection

  # --- CRITICAL FOR READ REPLICA ---
  replicate_source_db_instance_arn = var.source_db_instance_arn

  # Parameters like engine, engine_version, db_name, username, password, port
  # are INHERITED from the source when replicate_source_db_instance_arn is used.
  tags = {
    Name        = "${var.environment_tag}-${var.region}-db-instance-replica"
    Environment = var.environment_tag
  }
  # Ensure the password is generated even if not directly used by replica,
  # as it would be needed if the replica is promoted.
  depends_on = [random_password.db_master_password]
}


# AWS Secrets Manager Secret for DB Credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  provider = aws
  name        = "${var.environment_tag}/${var.region}/db-credentials"
  description = "RDS ${var.db_engine} master user credentials for ${var.environment_tag} in ${var.region}"
  tags = {
    Environment = var.environment_tag
    Region      = var.region
    Name        = "${var.environment_tag}-${var.region}-db-credentials"
  }
}

# Store the generated password and username in the Secrets Manager secret
resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  provider = aws
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_master_username # This is the username for the source/promoted instance
    password = random_password.db_master_password.result # This password is for the source/promoted instance
    db_name  = var.db_name
    engine   = var.db_engine
    # Dynamically select host based on which instance type is created
    host     = var.source_db_instance_arn == null ? aws_db_instance.main[0].address : aws_db_instance.read_replica[0].address
    port     = var.db_port
  })
  # Ensure the correct DB instance is created and password generated before storing secret
  depends_on = [
    aws_db_instance.main,
    aws_db_instance.read_replica, # Depend on both, only one will be active
    random_password.db_master_password
  ]
}
