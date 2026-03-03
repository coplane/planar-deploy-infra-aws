# Example: Deploy Planar into an existing VPC
#
# Use this when you already have a VPC with public and private subnets.
# Your VPC must have:
#   - Private subnets with NAT gateway access (for ECS tasks to reach AWS APIs)
#   - Public subnets (for the ALB, if internet-facing)
#   - DNS support and DNS hostnames enabled

terraform {
  required_version = ">= 1.0"
  backend "s3" {}
}

provider "aws" {
  region = "us-east-1"
}

module "planar" {
  source = "../../"

  app_name         = "myapp"
  stage            = "prod"
  aws_region       = "us-east-1"
  base_domain_name = "example.com"
  hosted_zone_id   = "Z0123456789ABCDEF"

  vpc_id      = "vpc-0123456789abcdef0"
  subnets     = ["subnet-aaa", "subnet-bbb"]
  alb_subnets = ["subnet-ccc", "subnet-ddd"]

  container_registry_url = "ghcr.io"
  container_image_name   = "coplane/planar-demo-public"
  container_image_tag    = "latest"

  # Alternatively, you can create ECR and import the public demo image to it using:
  # import_image_to_ecr = true
  # repository_name     = "myapp-repo"

  workos_client_id = "client_xxx"
  workos_org_id    = "org_yyy"
}

output "app_endpoint_url" {
  description = "The full endpoint url of the application"
  value       = module.planar.domain_name
}
