# Outputs for the networking module
output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets."
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "List of Availability Zones used."
  value       = data.aws_availability_zones.available.names
}

# New outputs for unique route table IDs
output "public_route_table_id" {
  description = "The ID of the single public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "List of IDs of the private route tables (one per private subnet)."
  value       = aws_route_table.private[*].id
}
