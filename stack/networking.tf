# VPC — simple-public topology per RUNTIME_DECISION.md § 1 + § 3:
# - Public subnets: ALB + Fargate tasks (public IP, SG-only inbound)
# - Private subnets: RDS only (no public IP, no NAT)
# No NAT gateway — outbound from tasks goes over the public IP to AWS endpoints.

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az_a = data.aws_availability_zones.available.names[0]
  az_b = data.aws_availability_zones.available.names[1]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "intentproof-vpc" }
}

# ── Public subnets (ALB + Fargate tasks) ─────────────────────────────────────

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = local.az_a
  map_public_ip_on_launch = false # tasks request public IP via assignPublicIp in service def

  tags = { Name = "intentproof-public-${local.az_a}" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone       = local.az_b
  map_public_ip_on_launch = false

  tags = { Name = "intentproof-public-${local.az_b}" }
}

# ── Private subnets (RDS only) ───────────────────────────────────────────────

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 11)
  availability_zone = local.az_a

  tags = { Name = "intentproof-private-${local.az_a}" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 12)
  availability_zone = local.az_b

  tags = { Name = "intentproof-private-${local.az_b}" }
}

# ── Internet Gateway + routing for public subnets ────────────────────────────

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "intentproof-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "intentproof-public-rt" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# ── Security groups ───────────────────────────────────────────────────────────
# Three-tier model per RUNTIME_DECISION.md § 3:
#   sg-alb   → accepts 443; :80 optional when var.alb_accept_http (redirect to HTTPS)
#   sg-tasks → accepts 8000 from sg-alb only; outbound unrestricted (public IP → AWS endpoints)
#   sg-rds   → accepts 5432 from sg-tasks only

resource "aws_security_group" "alb" {
  name        = "intentproof-alb"
  description = "ALB: inbound HTTPS+HTTP from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  dynamic "ingress" {
    for_each = var.alb_accept_http ? [1] : []
    content {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP redirect from internet"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "intentproof-alb-sg" }
}

resource "aws_security_group" "tasks" {
  name        = "intentproof-tasks"
  description = "Fargate tasks: inbound from ALB only, unrestricted outbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "App port from ALB only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Outbound to AWS endpoints (SQS, ECR, Secrets Manager) over public IP"
  }

  tags = { Name = "intentproof-tasks-sg" }
}

resource "aws_security_group" "rds" {
  name        = "intentproof-rds"
  description = "RDS: inbound from Fargate tasks only"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.tasks.id]
    description     = "PostgreSQL from tasks only"
  }

  tags = { Name = "intentproof-rds-sg" }
}
