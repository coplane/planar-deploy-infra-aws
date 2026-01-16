variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile to use for authentication"
  type        = string
  default     = null
}

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "stage" {
  description = "Stage/environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.stage)
    error_message = "Stage must be one of: dev, staging, prod."
  }
}

variable "base_domain_name" {
  description = "Base domain name for Route53 hosted zone"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "subnets" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "alb_subnets" {
  description = "List of public subnet IDs for the ALB (required for internet-facing ALBs)"
  type        = list(string)
  default     = null
}

variable "container_cpu" {
  description = "CPU units for the container (1024 = 1 vCPU)"
  type        = number
  default     = 2048
}

variable "container_memory" {
  description = "Memory for the container in MB"
  type        = number
  default     = 4096
}

variable "desired_count" {
  description = "Desired number of running tasks"
  type        = number
  default     = 1
}

variable "aurora_min_capacity" {
  description = "Minimum Aurora Serverless v2 capacity (ACUs)"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Maximum Aurora Serverless v2 capacity (ACUs)"  
  type        = number
  default     = 2.0
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for S3 CORS"
  type        = list(string)
  default = [
    "https://staging.coplane.com",
    "https://staging.coplane.com/",
    "https://app.coplane.com",
    "https://app.coplane.com/"
  ]
}

variable "container_registry_url" {
  description = "Base URL of the private container registry (e.g., ghcr.io, docker.io, registry.example.com)"
  type        = string
}

variable "container_image_name" {
  description = "Full image path including owner/repo (e.g., owner/repo or username/repo)"
  type        = string
}

variable "container_image_tag" {
  description = "Image tag or digest to deploy"
  type        = string
  default     = "latest"
}

variable "container_registry_username" {
  description = "Username for container registry authentication. Required only for private registries."
  type        = string
  default     = null
}

variable "container_registry_password" {
  description = "Password or token for container registry authentication. Required only for private registries."
  type        = string
  sensitive   = true
  default     = null
}

variable "alb_internal" {
  description = "Whether the ALB should be internal (not accessible from internet)"
  type        = bool
  default     = false
}

variable "waf_web_acl_arn" {
  description = "ARN of the WAFv2 Web ACL to associate with the ALB. If not provided, no WAF association will be created."
  type        = string
  default     = null
}

variable "repository_name" {
  description = "Name of the ECR repository. If provided, a private ECR repository will be created."
  type        = string
  default     = null
}

variable "workos_client_id" {
  description = "WorkOS client ID"
  type        = string
}

variable "workos_org_id" {
  description = "WorkOS organization ID"
  type        = string
}