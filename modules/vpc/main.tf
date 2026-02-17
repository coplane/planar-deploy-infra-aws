terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.availability_zone_count)

  nat_gateway_count = var.single_nat_gateway ? 1 : var.availability_zone_count
}

# ------------------------------------------------------------------------------
# VPC
# ------------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = var.name
  })
}

# ------------------------------------------------------------------------------
# Default Security Group
# ------------------------------------------------------------------------------

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  # No ingress or egress rules = "Deny All"

  tags = merge(var.tags, {
    Name = "${var.name}-default"
  })
}

# ------------------------------------------------------------------------------
# Internet Gateway
# ------------------------------------------------------------------------------

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = var.name
  })
}

# ------------------------------------------------------------------------------
# Public Subnets
# ------------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = var.availability_zone_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr_block, 4, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name}-public-${local.azs[count.index]}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-public"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = var.availability_zone_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# NAT Gateway(s)
# ------------------------------------------------------------------------------

resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-nat-${local.azs[count.index]}"
  })
}

resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.name}-nat-${local.azs[count.index]}"
  })

  depends_on = [aws_internet_gateway.this]
}

# ------------------------------------------------------------------------------
# Private Subnets
# ------------------------------------------------------------------------------

resource "aws_subnet" "private" {
  count = var.availability_zone_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr_block, 4, count.index + 8)
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-private-${local.azs[count.index]}"
  })
}

resource "aws_route_table" "private" {
  count = local.nat_gateway_count

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = var.single_nat_gateway ? "${var.name}-private" : "${var.name}-private-${local.azs[count.index]}"
  })
}

resource "aws_route" "private_nat" {
  count = local.nat_gateway_count

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "private" {
  count = var.availability_zone_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}

# ------------------------------------------------------------------------------
# S3 Endpoint
# ------------------------------------------------------------------------------

data "aws_region" "current" {}

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id       = aws_vpc.this.id
  service_name = "com.amazonaws.${data.aws_region.current.id}.s3"

  tags = merge(var.tags, {
    Name = "${var.name}-s3"
  })
}

resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  count = var.enable_s3_endpoint ? local.nat_gateway_count : 0

  route_table_id  = aws_route_table.private[count.index].id
  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
}

resource "aws_vpc_endpoint_route_table_association" "public_s3" {
  count = var.enable_s3_endpoint ? 1 : 0

  route_table_id  = aws_route_table.public.id
  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
}

# ------------------------------------------------------------------------------
# VPC Flow Logs
# ------------------------------------------------------------------------------

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.flow_log[0].arn
  log_destination = aws_cloudwatch_log_group.flow_log[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-flow-log"
  })
}

resource "aws_cloudwatch_log_group" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.name}-flow-log"
  retention_in_days = var.flow_logs_retention_in_days

  tags = merge(var.tags, {
    Name = "${var.name}-flow-log"
  })
}

resource "aws_iam_role" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name}-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name}-vpc-flow-log-role"
  })
}

resource "aws_iam_role_policy" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name}-vpc-flow-log-policy"
  role = aws_iam_role.flow_log[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
