terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
    }
  }
}

locals {
  suffix           = "-${var.stage}-${var.app_name}"
  full_domain_name = "${var.app_name}-${var.stage}.${var.base_domain_name}"
  zone_id          = var.hosted_zone_id

  common_tags = {
    "framework"         = "planar"
    "framework.version" = "0.17"
    "stage"             = var.stage
    "app.name"          = var.app_name
    "app.version"       = "0.0.1"
    "vendor_name"       = "CoPlane"
    "vendor_contact"    = "support@coplane.com"
  }
}

data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_region" "current" {}
