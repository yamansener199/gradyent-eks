# Public ALB TLS via ACM (DNS validation in Route 53). Replaces in-cluster cert-manager.

locals {
  create_platform_acm = var.bootstrap_ingress_dns_before_argocd && var.acm_certificate_arn == null

  platform_acm_certificate_arn = var.bootstrap_ingress_dns_before_argocd ? coalesce(
    var.acm_certificate_arn,
    try(aws_acm_certificate_validation.platform[0].certificate_arn, null),
  ) : null

  platform_acm_dvo = local.create_platform_acm ? one([
    for dvo in aws_acm_certificate.platform[0].domain_validation_options :
    dvo
    if dvo.domain_name == var.platform_domain
  ]) : null

  # Key by platform_domain so state matches apex-only record (wildcard shares the same CNAME).
  platform_acm_validation_records = local.create_platform_acm ? {
    (var.platform_domain) = {
      name   = local.platform_acm_dvo.resource_record_name
      record = local.platform_acm_dvo.resource_record_value
      type   = local.platform_acm_dvo.resource_record_type
    }
  } : {}
}

resource "aws_acm_certificate" "platform" {
  count = local.create_platform_acm ? 1 : 0

  domain_name               = var.platform_domain
  subject_alternative_names = ["*.${var.platform_domain}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-platform"
  })
}

resource "aws_route53_record" "platform_acm_validation" {
  for_each = local.platform_acm_validation_records

  allow_overwrite = true
  zone_id         = coalesce(var.route53_zone_id, data.aws_route53_zone.platform[0].zone_id) # from platform-dns.tf
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
}

resource "aws_acm_certificate_validation" "platform" {
  count = local.create_platform_acm ? 1 : 0

  certificate_arn         = aws_acm_certificate.platform[0].arn
  validation_record_fqdns = [for r in aws_route53_record.platform_acm_validation : r.fqdn]
}
