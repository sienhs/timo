resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-igw"
  }
}

# ALB requires public subnets in at least two Availability Zones.
resource "aws_subnet" "public_primary" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.primary_az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-public-${var.primary_az}"
    Tier = "public"
  }
}

resource "aws_subnet" "public_secondary" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.secondary_az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-public-${var.secondary_az}"
    Tier = "public"
  }
}

resource "aws_subnet" "private_app" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = var.primary_az

  tags = {
    Name = "${var.name}-app-${var.primary_az}"
    Tier = "private-app"
  }
}

# RDS DB subnet groups require subnets in at least two AZs,
# even when the DB instance itself is Single-AZ.
resource "aws_subnet" "db_primary" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = var.primary_az

  tags = {
    Name = "${var.name}-db-${var.primary_az}"
    Tier = "private-db"
  }
}

resource "aws_subnet" "db_secondary" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.22.0/24"
  availability_zone = var.secondary_az

  tags = {
    Name = "${var.name}-db-${var.secondary_az}"
    Tier = "private-db"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public_primary" {
  subnet_id      = aws_subnet.public_primary.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_secondary" {
  subnet_id      = aws_subnet.public_secondary.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-private-app-rt"
  }
}

resource "aws_route_table_association" "private_app" {
  subnet_id      = aws_subnet.private_app.id
  route_table_id = aws_route_table.private_app.id
}

# No Internet route here: RDS remains isolated.
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-db-rt"
  }
}

resource "aws_route_table_association" "db_primary" {
  subnet_id      = aws_subnet.db_primary.id
  route_table_id = aws_route_table.db.id
}

resource "aws_route_table_association" "db_secondary" {
  subnet_id      = aws_subnet.db_secondary.id
  route_table_id = aws_route_table.db.id
}
