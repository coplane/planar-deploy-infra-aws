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

  # ECR repository name to create.
  # Default public demo image will be pushed on terraform apply.
  # ghcr.io/coplane/planar-demo-public:latest
  repository_name = "myapp-repo"

  # WorkOS authentication
  workos_client_id = "client_01JSJHJPKG09TMSK6NHJP0S180"
  workos_org_id    = "org_01JY4QP57Y7H4EQ7HT3BGN7TNK"
}
output "app_endpoint_url" {
  description = "The full endpoint url of the application"
  value       = module.planar.domain_name
}