output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (use for alb_subnets)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (use for subnets)"
  value       = aws_subnet.private[*].id
}

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 VPC Endpoint"
  value       = var.enable_s3_endpoint ? aws_vpc_endpoint.s3[0].id : null
}
