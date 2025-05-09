data "aws_availability_zones" "available" {}

locals {
  all_ips           = "0.0.0.0/0"
  vpc_cidr          = "10.0.0.0/16"
  subnet_bits       = 8
  public_subnet_id  = 0
  private_subnet_id = 1
}

resource "aws_vpc" "vpc" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "subnet" {
  count             = 2
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, local.subnet_bits, count.index + 1)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "private"
  }
}

resource "aws_route" "private_route" {
  destination_cidr_block = local.all_ips
  nat_gateway_id         = aws_nat_gateway.nat.id
  route_table_id         = aws_route_table.private.id
}

resource "aws_route" "public_route" {
  destination_cidr_block = local.all_ips
  gateway_id             = aws_internet_gateway.igw.id
  route_table_id         = aws_route_table.public.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.subnet[local.public_subnet_id].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.subnet[local.private_subnet_id].id
  route_table_id = aws_route_table.private.id
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.subnet[local.public_subnet_id].id

  tags = {
    Name = "nat"
  }
}

resource "aws_eip" "nat" {
  tags = {
    Name = "nat"
  }
}

