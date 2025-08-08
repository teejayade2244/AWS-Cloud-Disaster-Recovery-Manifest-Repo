# --- VPC Peering Connection Module Resources ---

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws.primary, aws.secondary]
    }
  }
}

# 1. Create VPC Peering Connection (initiated from primary region)
resource "aws_vpc_peering_connection" "main" {
  provider      = aws.primary # Initiated from the primary region's provider
  peer_vpc_id   = var.secondary_vpc_id
  vpc_id        = var.primary_vpc_id
  peer_region   = var.secondary_region # Specify the peer region
  auto_accept   = true # Auto-accept since it's same account

  tags = {
    Name = "aura-flow-primary-to-secondary-peering"
  }
}

# No aws_vpc_peering_connection_accepter needed if auto_accept = true and same account

# --- Route Table Updates ---
# We need to add routes to ALL primary and secondary public/private subnets' route tables.
# Data sources to retrieve the route table IDs from the networking module's outputs.

data "aws_route_table" "primary_public_subnet_route_tables" {
  provider = aws.primary
  count    = length(var.primary_public_subnet_ids)
  vpc_id   = var.primary_vpc_id
  filter {
    name   = "association.subnet-id"
    values = [var.primary_public_subnet_ids[count.index]]
  }
}

data "aws_route_table" "primary_private_subnet_route_tables" {
  provider = aws.primary
  count    = length(var.primary_private_subnet_ids)
  vpc_id   = var.primary_vpc_id
  filter {
    name   = "association.subnet-id"
    values = [var.primary_private_subnet_ids[count.index]]
  }
}

data "aws_route_table" "secondary_public_subnet_route_tables" {
  provider = aws.secondary
  count    = length(var.secondary_public_subnet_ids)
  vpc_id   = var.secondary_vpc_id
  filter {
    name   = "association.subnet-id"
    values = [var.secondary_public_subnet_ids[count.index]]
  }
}

data "aws_route_table" "secondary_private_subnet_route_tables" {
  provider = aws.secondary
  count    = length(var.secondary_private_subnet_ids)
  vpc_id   = var.secondary_vpc_id
  filter {
    name   = "association.subnet-id"
    values = [var.secondary_private_subnet_ids[count.index]]
  }
}

# Add routes to ALL primary public subnets' route tables for secondary VPC CIDR
resource "aws_route" "primary_public_to_secondary" {
  provider                  = aws.primary
  count                     = length(var.primary_public_subnet_ids)
  route_table_id            = element(data.aws_route_table.primary_public_subnet_route_tables.*.id, count.index)
  destination_cidr_block    = var.secondary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  # Ensure peering is established before adding routes
  depends_on = [
    aws_vpc_peering_connection.main
  ]
}

# Add routes to ALL primary private subnets' route tables for secondary VPC CIDR
resource "aws_route" "primary_private_to_secondary" {
  provider                  = aws.primary
  count                     = length(var.primary_private_subnet_ids)
  route_table_id            = element(data.aws_route_table.primary_private_subnet_route_tables.*.id, count.index)
  destination_cidr_block    = var.secondary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  # Ensure peering is established before adding routes
  depends_on = [
    aws_vpc_peering_connection.main
  ]
}

# Add routes to ALL secondary public subnets' route tables for primary VPC CIDR
resource "aws_route" "secondary_public_to_primary" {
  provider                  = aws.secondary
  count                     = length(var.secondary_public_subnet_ids)
  route_table_id            = element(data.aws_route_table.secondary_public_subnet_route_tables.*.id, count.index)
  destination_cidr_block    = var.primary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  depends_on = [
    aws_vpc_peering_connection.main
  ]
}

# Add routes to ALL secondary private subnets' route tables for primary VPC CIDR
resource "aws_route" "secondary_private_to_primary" {
  provider                  = aws.secondary
  count                     = length(var.secondary_private_subnet_ids)
  route_table_id            = element(data.aws_route_table.secondary_private_subnet_route_tables.*.id, count.index)
  destination_cidr_block    = var.primary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  depends_on = [
    aws_vpc_peering_connection.main
  ]
}
