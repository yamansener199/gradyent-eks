data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # /16 VPC: public /20, private /20, intra /20 per AZ
  public_subnets  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + var.az_count)]
  intra_subnets   = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + (var.az_count * 2))]

  cluster_tag = "kubernetes.io/cluster/${var.cluster_name}"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.16"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets
  intra_subnets   = local.intra_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Intra subnets: no default route to NAT/IGW (control plane ENIs only)
  create_database_subnet_route_table = false

  public_subnet_tags = {
    (local.cluster_tag)                   = "shared"
    "kubernetes.io/role/elb"              = "1"
    "subnet-type"                         = "public"
  }

  private_subnet_tags = {
    (local.cluster_tag)                   = "shared"
    "kubernetes.io/role/internal-elb"     = "1"
    "karpenter.sh/discovery"              = var.cluster_name
    "subnet-type"                         = "private"
  }

  intra_subnet_tags = {
    (local.cluster_tag) = "shared"
    "subnet-type"       = "intra"
  }

  tags = var.tags
}

# VPC endpoints to reduce NAT dependency
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(module.vpc.private_route_table_ids, module.vpc.intra_route_table_ids)

  tags = merge(var.tags, { Name = "${var.cluster_name}-s3-endpoint" })
}

# Interface endpoints: core AWS APIs + SSM (Session Manager for bastion, no SSH).
locals {
  interface_endpoints = {
    ec2         = "com.amazonaws.${var.aws_region}.ec2"
    ecr_api     = "com.amazonaws.${var.aws_region}.ecr.api"
    ecr_dkr     = "com.amazonaws.${var.aws_region}.ecr.dkr"
    sts         = "com.amazonaws.${var.aws_region}.sts"
    logs        = "com.amazonaws.${var.aws_region}.logs"
    ssm         = "com.amazonaws.${var.aws_region}.ssm"
    ssmmessages = "com.amazonaws.${var.aws_region}.ssmmessages"
    ec2messages = "com.amazonaws.${var.aws_region}.ec2messages"
  }
}

resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.cluster_name}-vpce-"
  description = "Security group for VPC interface endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-vpce-sg" })
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = module.vpc.vpc_id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${var.cluster_name}-${each.key}-endpoint" })
}
