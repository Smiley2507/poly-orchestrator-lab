# Dedicated VPC for the lab: 2 AZs, public subnets for the internet-facing ALB
# and NAT Gateway, private subnets for ECS tasks, RDS and ElastiCache.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  # Private ECS tasks need outbound internet access to pull container images from
  # ECR and reach required AWS endpoints (Service Connect/Cloud Map depend on DNS,
  # not on the NAT path itself, but image pulls and AWS API calls do).
  #
  # One NAT Gateway (rather than one per AZ) is sufficient for this lab and keeps
  # costs lower. Production HA designs may use one NAT Gateway per AZ.
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  # ECS Service Connect / Cloud Map rely on VPC DNS resolution.
  enable_dns_support   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    Tier = "public"
  }

  private_subnet_tags = {
    Tier = "private"
  }

  tags = local.common_tags
}
