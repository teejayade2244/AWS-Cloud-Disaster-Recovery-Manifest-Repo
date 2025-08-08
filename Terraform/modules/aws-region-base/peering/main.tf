# # Create VPC Peering Connection (initiated from primary region)
# resource "aws_vpc_peering_connection" "main" {
#   provider      = aws.primary 
#   peer_vpc_id   = var.secondary_vpc_id
#   vpc_id        = var.primary_vpc_id
#   peer_region   = var.secondary_region 

#   tags = {
#     Name = "aura-flow-primary-to-secondary-peering"
#   }
# }

# # 2. Accept VPC Peering Connection (in the secondary region)
# resource "aws_vpc_peering_connection_accepter" "main" {
#   provider                  = aws.secondary 
#   vpc_peering_connection_id = aws_vpc_peering_connection.main.id
#   auto_accept               = true

#   tags = {
#     Name = "aura-flow-secondary-accepted-peering"
#   }
# }

# # 3. Add Route to Primary VPC's Public Route Table for Secondary VPC CIDR
# # Find the default public route table in the primary VPC
# data "aws_route_table" "primary_public" {
#   provider = aws.primary
#   vpc_id   = var.primary_vpc_id
#   filter {
#     name   = "association.main"
#     values = ["true"] # Assuming the main route table is the public one or is associated with public subnets
#   }
#   # Attempt to find the route table explicitly associated with one of the public subnets
#   # If you have specific names for your public route tables, use that instead.
#   # For this example, we assume it's the main route table or associated correctly.
#   # A more robust approach might query by name if you tag your route tables specifically.
#   # For now, let's assume one of the public subnets' associated route tables is suitable.
#   # Using an explicit data source for the public route table from the networking module outputs
#   depends_on = [
#     aws_vpc_peering_connection.main,
#     aws_vpc_peering_connection_accepter.main
#   ]
# }


# # To correctly get the public route tables, we need to import them from the networking module's outputs.
# # This means the route table update should likely happen in the root main.tf or be more explicit here
# # by using external data source to find the correct route tables.
# # Given the previous networking module created routes per subnet, we need to iterate.

# # Add routes to ALL primary public subnets' route tables
# resource "aws_route" "primary_public_to_secondary" {
#   provider                  = aws.primary
#   count                     = length(var.primary_public_subnet_ids) # Iterate over public subnets
#   route_table_id            = element(data.aws_route_table.primary_public_subnet_route_tables.*.id, count.index) # Use data source to get IDs
#   destination_cidr_block    = var.secondary_vpc_cidr
#   vpc_peering_connection_id = aws_vpc_peering_connection.main.id

#   # Ensure peering is established before adding routes
#   depends_on = [
#     aws_vpc_peering_connection.main,
#     aws_vpc_peering_connection_accepter.main
#   ]
# }

# # Add routes to ALL primary private subnets' route tables
# resource "aws_route" "primary_private_to_secondary" {
#   provider                  = aws.primary
#   count                     = length(var.primary_private_subnet_ids) # Iterate over private subnets
#   route_table_id            = element(data.aws_route_table.primary_private_subnet_route_tables.*.id, count.index) # Use data source to get IDs
#   destination_cidr_block    = var.secondary_vpc_cidr
#   vpc_peering_connection_id = aws_vpc_peering_connection.main.id

#   # Ensure peering is established before adding routes
#   depends_on = [
#     aws_vpc_peering_connection.main,
#     aws_vpc_peering_connection_accepter.main
#   ]
# }


# # 4. Add Route to Secondary VPC's Public Route Table for Primary VPC CIDR
# # Find the default public route table in the secondary VPC
# data "aws_route_table" "secondary_public" {
#   provider = aws.secondary
#   vpc_id   = var.secondary_vpc_id
#   filter {
#     name   = "association.main"
#     values = ["true"] # Assuming the main route table is the public one or is associated with public subnets
#   }
#   depends_on = [
#     aws_vpc_peering_connection.main,
#     aws_vpc_peering_connection_accepter.main
#   ]
# }

# # Add routes to ALL secondary public subnets' route tables
# resource "aws_route" "secondary_public_to_primary" {
#   provider                  = aws.secondary
#   count                     = length(var.secondary_public_subnet_ids) # Iterate over public subnets
#   route_table_id            = element(data.aws_route_table.secondary_public_subnet_route_tables.*.id, count.index) # Use data source to get IDs
#   destination_cidr_block    = var.primary_vpc_cidr
#   vpc_peering_connection_id = aws_vpc_peering_connection.main.id

#   depends_on = [
#     aws_vpc_peering_connection.main,
#     aws_vpc_peering_connection_accepter.main
#   ]
# }

# # Add routes to ALL secondary private subnets' route tables
# resource "aws_route" "secondary_private_to_primary" {
#   provider                  = aws.secondary
#   count                     = length(var.secondary_private_subnet_ids) # Iterate over private subnets
#   route_table_id            = element(data.aws_route_table.secondary_private_subnet_route_tables.*.id, count.index) # Use data source to get IDs
#   destination_cidr_block    = var.primary_vpc_cidr
#   vpc_peering_connection_id = aws_vpc_peering_connection.main.id

#   depends_on = [
#     aws_vpc_peering_connection.main,
#     aws_vpc_peering_connection_accepter.main
#   ]
# }

# # --- Data sources to retrieve the route table IDs from the networking module's outputs ---
# # This is crucial because the networking module creates *multiple* route tables (one per private subnet, one public).
# # We need to query for them using tags or associations from the networking module's output.

# data "aws_route_table" "primary_public_subnet_route_tables" {
#   provider = aws.primary
#   count    = length(var.primary_public_subnet_ids)
#   vpc_id   = var.primary_vpc_id
#   filter {
#     name   = "association.subnet-id"
#     values = [var.primary_public_subnet_ids[count.index]]
#   }
# }

# data "aws_route_table" "primary_private_subnet_route_tables" {
#   provider = aws.primary
#   count    = length(var.primary_private_subnet_ids)
#   vpc_id   = var.primary_vpc_id
#   filter {
#     name   = "association.subnet-id"
#     values = [var.primary_private_subnet_ids[count.index]]
#   }
# }

# data "aws_route_table" "secondary_public_subnet_route_tables" {
#   provider = aws.secondary
#   count    = length(var.secondary_public_subnet_ids)
#   vpc_id   = var.secondary_vpc_id
#   filter {
#     name   = "association.subnet-id"
#     values = [var.secondary_public_subnet_ids[count.index]]
#   }
# }

# data "aws_route_table" "secondary_private_subnet_route_tables" {
#   provider = aws.secondary
#   count    = length(var.secondary_private_subnet_ids)
#   vpc_id   = var.secondary_vpc_id
#   filter {
#     name   = "association.subnet-id"
#     values = [var.secondary_private_subnet_ids[count.index]]
#   }
# }
