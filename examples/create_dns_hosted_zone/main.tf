terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

module "dns_zone" {
  source = "../../modules/dns"

  tenant_id     = "example-tenant"
  domain_suffix = "example.com"
}

output "hosted_zone_id" {
  value = module.dns_zone.zone_id
}

output "name_servers" {
  value = module.dns_zone.name_servers
}
