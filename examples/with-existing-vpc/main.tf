# Example: Deploy Planar into an existing VPC
#
# Use this when you already have a VPC with public and private subnets.
# Your VPC must have:
#   - Private subnets with NAT gateway access (for ECS tasks to reach AWS APIs)
#   - Public subnets (for the ALB, if internet-facing)
#   - DNS support and DNS hostnames enabled

module "planar" {
  source = "../../"

  app_name         = "myapp"
  stage            = "prod"
  aws_region       = "us-east-1"
  base_domain_name = "example.com"

  # Provide your existing VPC and subnets
  vpc_id      = "vpc-0123456789abcdef0"
  subnets     = ["subnet-aaa", "subnet-bbb"]
  alb_subnets = ["subnet-ccc", "subnet-ddd"]

  # Container configuration
  container_registry_url      = "ghcr.io"
  container_image_name        = "your-org/planar"
  container_image_tag         = "latest"
  container_registry_username = "your-username"
  container_registry_password = "your-token"

  # WorkOS authentication
  workos_client_id = "client_xxx"
  workos_org_id    = "org_xxx"
}
