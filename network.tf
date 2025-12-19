########################################
# Networking for the Alveriano Platform
########################################

# Discover available AZs in eu-west-2 so we can spread across at least two.
data "aws_availability_zones" "available" {
  state = "available"
}

# Pick the first two AZ names (e.g. eu-west-2a, eu-west-2b)
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

# Main VPC for all platform services
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "alveriano-main-vpc"
  }
}

# Public subnets (for things that can have public IPs, like load balancers)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = local.azs[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "alveriano-public-a"
    Tier = "public"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.azs[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "alveriano-public-b"
    Tier = "public"
  }
}

# Private subnets (for RDS and internal services with no public IP)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = local.azs[0]

  tags = {
    Name = "alveriano-private-a"
    Tier = "private"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = local.azs[1]

  tags = {
    Name = "alveriano-private-b"
    Tier = "private"
  }
}

# Internet gateway to give public subnets internet access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "alveriano-igw"
  }
}

# Route table for public subnets: send 0.0.0.0/0 to the internet gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "alveriano-public-rt"
  }
}

# Associate public subnets with the public route table
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}
