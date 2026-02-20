resource "aws_route53_zone" "tenant_zone" {
  name = "${var.tenant_id}.${var.domain_suffix}"
}
