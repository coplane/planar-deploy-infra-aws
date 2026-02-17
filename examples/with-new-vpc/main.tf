# Example: Deploy Planar with a new VPC
#
# Use this when you don't have an existing VPC. The VPC module creates
# everything you need: VPC, public/private subnets, NAT gateway, and
# route tables across multiple availability zones.

provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "../../modules/vpc"

  name       = "planar-prod"
  cidr_block = "10.0.0.0/16"

  # Use 2 AZs (default). Set to 3 for higher availability.
  availability_zone_count = 2

  # Single NAT gateway (default, cheaper). Set to false for one per AZ.
  single_nat_gateway = true

  tags = {
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

module "planar" {
  source = "../../"

  app_name         = "myapp"
  stage            = "prod"
  aws_region       = "us-east-1"
  base_domain_name = "example.com"

  # Wire VPC module outputs to Planar inputs
  vpc_id      = module.vpc.vpc_id
  subnets     = module.vpc.private_subnet_ids
  alb_subnets = module.vpc.public_subnet_ids

  # ECR repository name to create.
  # Default public demo image will be pushed on terraform apply.
  # ghcr.io/coplane/planar-demo-public:latest
  repository_name = "myapp-repo"

  # WorkOS authentication
  workos_client_id = "client_xxx"
  workos_org_id    = "org_xxx"
}
