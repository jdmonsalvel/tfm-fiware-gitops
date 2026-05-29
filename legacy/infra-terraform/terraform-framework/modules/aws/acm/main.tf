# ──────────────────────────────────────────────────────────────────────────────
# CERTIFICADOS ACM
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_acm_certificate" "cert" {
  for_each = var.acm_certificates

  domain_name               = each.value.domain_name
  subject_alternative_names = each.value.subject_alternative_names
  validation_method         = each.value.validation_method
  key_algorithm             = each.value.key_algorithm

  # Necesario para reutilizar el certificado activo mientras se provisiona el nuevo
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, each.value.tags, { Name = each.value.domain_name })
}

# ──────────────────────────────────────────────────────────────────────────────
# RECORDS CNAME DE VALIDACIÓN DNS EN ROUTE53
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_route53_record" "validation" {
  for_each = local.validation_records

  zone_id = var.zone_ids[each.value.zone_key]
  name    = each.value.record_name
  type    = each.value.record_type
  ttl     = 60
  records = [each.value.record_value]

  # ACM reutiliza el mismo CNAME para wildcard + apex del mismo dominio;
  # allow_overwrite evita error si el record ya existe de un cert anterior.
  allow_overwrite = true
}

# ──────────────────────────────────────────────────────────────────────────────
# ESPERAR VALIDACIÓN (bloquea hasta que ACM emite el certificado)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_acm_certificate_validation" "cert" {
  for_each = var.wait_for_validation ? local.dns_validated : {}

  certificate_arn = aws_acm_certificate.cert[each.key].arn

  validation_record_fqdns = [
    for dvo in aws_acm_certificate.cert[each.key].domain_validation_options :
    aws_route53_record.validation["${each.key}-${dvo.domain_name}"].fqdn
  ]

  depends_on = [aws_route53_record.validation]
}
