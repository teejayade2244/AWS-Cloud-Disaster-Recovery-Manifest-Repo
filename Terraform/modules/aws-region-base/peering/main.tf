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
# --- VPC Peering Connection Module Resources ---


# 1. Create VPC Peering Connection (initiated from primary region)
resource "aws_vpc_peering_connection" "main" {
  provider      = aws.primary
  peer_vpc_id   = var.secondary_vpc_id
  vpc_id        = var.primary_vpc_id
  auto_accept   = false # Request is sent, needs explicit acceptance
  peer_region   = var.secondary_region # Specify peer region for cross-region requests

  tags = {
    Name = "aura-flow-primary-to-secondary-peering"
  }
}

# 2. Accept VPC Peering Connection (in the secondary region)
resource "aws_vpc_peering_connection_accepter" "secondary" {
  provider                  = aws.secondary # Accepted by the secondary region's provider
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  auto_accept               = true # Automatically accept the peering request once it arrives

  tags = {
    Name = "accepter-secondary-side"
  }
}

# --- Route Table Updates ---
# REMOVED: All data "aws_route_table" blocks.
# Routes will now use direct inputs for route table IDs.

# Add route to primary public route table for secondary VPC CIDR
resource "aws_route" "primary_public_to_secondary" {
  provider                  = aws.primary
  # No 'count' here because there's only one public route table being targeted
  route_table_id            = var.primary_public_route_table_id # Use direct input
  destination_cidr_block    = var.secondary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  depends_on = [
    aws_vpc_peering_connection_accepter.secondary # Depends on acceptor being ready
  ]
}

# Add routes to ALL primary private route tables for secondary VPC CIDR
resource "aws_route" "primary_private_to_secondary" {
  provider                  = aws.primary
  count                     = length(var.primary_private_route_table_ids) # Count based on the list of private RT IDs
  route_table_id            = element(var.primary_private_route_table_ids, count.index) # Use direct input list
  destination_cidr_block    = var.secondary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  depends_on = [
    aws_vpc_peering_connection_accepter.secondary # Depends on acceptor being ready
  ]
}

# Add route to secondary public route table for primary VPC CIDR
resource "aws_route" "secondary_public_to_primary" {
  provider                  = aws.secondary
  # No 'count' here
  route_table_id            = var.secondary_public_route_table_id # Use direct input
  destination_cidr_block    = var.primary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  depends_on = [
    aws_vpc_peering_connection_accepter.secondary # Depends on acceptor being ready
  ]
}

# Add routes to ALL secondary private route tables for primary VPC CIDR
resource "aws_route" "secondary_private_to_primary" {
  provider                  = aws.secondary
  count                     = length(var.secondary_private_route_table_ids) # Count based on the list of private RT IDs
  route_table_id            = element(var.secondary_private_route_table_ids, count.index) # Use direct input list
  destination_cidr_block    = var.primary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  depends_on = [
    aws_vpc_peering_connection_accepter.secondary # Depends on acceptor being ready
  ]
}
