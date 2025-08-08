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
resource "aws_route" "primary_public_to_secondary" {
  provider                  = aws.primary
  count                     = length(var.primary_public_subnet_ids)
  route_table_id            = element(data.aws_route_table.primary_public_subnet_route_tables.*.id, count.index)
  destination_cidr_block    = var.secondary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  # Add lifecycle rule to ignore conflicts
  lifecycle {
    ignore_changes = [vpc_peering_connection_id]
  }

  depends_on = [
    aws_vpc_peering_connection_accepter.secondary
  ]
}

# Add the same lifecycle rule to all other route resources
resource "aws_route" "primary_private_to_secondary" {
  provider                  = aws.primary
  count                     = length(var.primary_private_subnet_ids)
  route_table_id            = element(data.aws_route_table.primary_private_subnet_route_tables.*.id, count.index)
  destination_cidr_block    = var.secondary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  lifecycle {
    ignore_changes = [vpc_peering_connection_id]
  }

  depends_on = [
    aws_vpc_peering_connection_accepter.secondary
  ]
}

resource "aws_route" "secondary_public_to_primary" {
  provider                  = aws.secondary
  count                     = length(var.secondary_public_subnet_ids)
  route_table_id            = element(data.aws_route_table.secondary_public_subnet_route_tables.*.id, count.index)
  destination_cidr_block    = var.primary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  lifecycle {
    ignore_changes = [vpc_peering_connection_id]
  }

  depends_on = [
    aws_vpc_peering_connection_accepter.secondary
  ]
}

resource "aws_route" "secondary_private_to_primary" {
  provider                  = aws.secondary
  count                     = length(var.secondary_private_subnet_ids)
  route_table_id            = element(data.aws_route_table.secondary_private_subnet_route_tables.*.id, count.index)
  destination_cidr_block    = var.primary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  lifecycle {
    ignore_changes = [vpc_peering_connection_id]
  }

  depends_on = [
    aws_vpc_peering_connection_accepter.secondary
  ]
}