terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws]
    }
  }
}

data "aws_availability_zones" "available" {
  state    = "available"
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "aura-flow-${var.region}-vpc"
    Environment = var.environment_tag
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id   = aws_vpc.main.id

  tags = {
    Name = "aura-flow-${var.region}-igw"
  }
}

# Create Public Subnets (across multiple AZs)
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true 

  tags = {
    Name        = "aura-flow-${var.region}-public-subnet-${count.index + 1}"
    Environment = var.environment_tag
  }
}

# Create Private Subnets (across multiple AZs)
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "aura-flow-${var.region}-private-subnet-${count.index + 1}"
    Environment = var.environment_tag
  }
}

# Create Elastic IPs for NAT Gateways (one per public subnet/AZ)
resource "aws_eip" "nat_eip" {
  count    = length(aws_subnet.public)
  tags = {
    Name = "aura-flow-${var.region}-nat-eip-${count.index + 1}"
  }
}

# Create NAT Gateways (one per public subnet/AZ)
resource "aws_nat_gateway" "main" {
  count         = length(aws_subnet.public)
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.main]

  tags = {
    Name = "aura-flow-${var.region}-nat-gateway-${count.index + 1}"
  }
}

# Create Public Route Table
resource "aws_route_table" "public" {
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "aura-flow-${var.region}-public-rt"
  }
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Create Private Route Tables (one per private subnet/AZ, routing through NAT Gateway)
resource "aws_route_table" "private" {
  count    = length(aws_subnet.private)
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "aura-flow-${var.region}-private-rt-${count.index + 1}"
  }
}

# Associate Private Subnets with Private Route Tables
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
