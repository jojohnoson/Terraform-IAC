# --- 1. VPC Definition ---
resource "aws_vpc" "ha_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "HA-VPC-1"
  }
}

# Note: Following the /20 CIDR blocks shown in your Resource Map

# AZ1 Subnets
resource "aws_subnet" "pub_ha_az1" {
  vpc_id            = aws_vpc.ha_vpc.id
  cidr_block        = "10.0.0.0/20"
  availability_zone = "ap-south-1a"
  tags = { Name = "pub-HA-1-AZ1" }
}

resource "aws_subnet" "pri_ha_app_az1" {
  vpc_id            = aws_vpc.ha_vpc.id
  cidr_block        = "10.0.128.0/20"
  availability_zone = "ap-south-1a"
  tags = { Name = "pri-HA-App-AZ1" } # App Tier
}

resource "aws_subnet" "pri_ha_db_az1" {
  vpc_id            = aws_vpc.ha_vpc.id
  cidr_block        = "10.0.160.0/20"
  availability_zone = "ap-south-1a"
  tags = { Name = "pri-HA-DB-AZ1" } # DB Tier
}

# AZ2 Subnets
resource "aws_subnet" "pub_ha_az2" {
  vpc_id            = aws_vpc.ha_vpc.id
  cidr_block        = "10.0.16.0/20"
  availability_zone = "ap-south-1b"
  tags = { Name = "pub-HA-2-AZ2" }
}

resource "aws_subnet" "pri_ha_app_az2" {
  vpc_id            = aws_vpc.ha_vpc.id
  cidr_block        = "10.0.176.0/20"
  availability_zone = "ap-south-1b"
  tags = { Name = "pri-HA-App2-AZ2" } # App Tier
}

resource "aws_subnet" "pri_ha_db_az2" {
  vpc_id            = aws_vpc.ha_vpc.id
  cidr_block        = "10.0.144.0/20"
  availability_zone = "ap-south-1b"
  tags = { Name = "pri-HA-DB2-AZ2" } # DB Tier
}

# --- 3. Gateways ---

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.ha_vpc.id
  tags   = { Name = "igw-HA-1" }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.pub_ha_az1.id # Placed in Public AZ1
  tags          = { Name = "NAT-HA-1" }
}

resource "aws_eip" "nat_eip2"{
  domain = "vpc"
}

resource "aws_nat_gateway" "nat2"{
  allocation_id = aws_eip.nat_eip2.id
  subnet_id     = aws_subnet.pub_ha_az2.id # Placed in Public AZ2
  tags          = { Name = "NAT-HA-2" }
}


# --- 4. Route Tables (Strictly following the Last Image associations) ---

# Public Route Table
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.ha_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "Pub-rt-1" }
}

# Private Route Tables (Pointing to NAT Gateway)
resource "aws_route_table" "pri_rt_1" {
  vpc_id = aws_vpc.ha_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "pri-rt-1" }
}

resource "aws_route_table" "pri_rt_2" {
  vpc_id = aws_vpc.ha_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat2.id
  }
  tags = { Name = "pri-rt-2" }
}

resource "aws_route_table" "pri_rt_3" {
  vpc_id = aws_vpc.ha_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "pri-rt-3" }
}

resource "aws_route_table" "pri_rt_4" {
  vpc_id = aws_vpc.ha_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat2.id
  }
  tags = { Name = "pri-rt-4" }
}

# --- 5. Route Table Associations ---

# Public Subnets
# Attaching igw to the pub subnet in AZ1 as well to ensure high availability
resource "aws_route_table_association" "pub_1" {
  subnet_id      = aws_subnet.pub_ha_az1.id
  route_table_id = aws_route_table.pub_rt.id
}
# Attaching igw to the pub subnet in AZ2 as well to ensure high availability
resource "aws_route_table_association" "pub_2" {
  subnet_id      = aws_subnet.pub_ha_az2.id
  route_table_id = aws_route_table.pub_rt.id
}

# Attaching the Subnets to Route Tables that contain a path to the NAT Gateway.
# Private Subnets (Mapping to the 4 Private RTs as per map)
resource "aws_route_table_association" "pri_1" {
  subnet_id      = aws_subnet.pri_ha_app_az1.id
  route_table_id = aws_route_table.pri_rt_1.id
}
resource "aws_route_table_association" "pri_2" {
  subnet_id      = aws_subnet.pri_ha_app_az2.id
  route_table_id = aws_route_table.pri_rt_2.id
}
resource "aws_route_table_association" "pri_3" {
  subnet_id      = aws_subnet.pri_ha_db_az1.id
  route_table_id = aws_route_table.pri_rt_3.id
}
resource "aws_route_table_association" "pri_4" {
  subnet_id      = aws_subnet.pri_ha_db_az2.id
  route_table_id = aws_route_table.pri_rt_4.id
}