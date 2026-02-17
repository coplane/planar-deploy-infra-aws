output "name_servers" {
  description = "Name servers for the hosted zone"
  value       = aws_route53_zone.tenant_zone.name_servers
}

output "zone_id" {
  description = "Zone ID of the hosted zone"
  value       = aws_route53_zone.tenant_zone.zone_id
}
