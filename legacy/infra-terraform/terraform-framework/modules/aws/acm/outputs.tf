output "certificate_arns" {
  description = "Map de nombre_clave → ARN del certificado ACM"
  value       = { for k, v in aws_acm_certificate.cert : k => v.arn }
}

output "certificate_domain_names" {
  description = "Map de nombre_clave → dominio principal del certificado"
  value       = { for k, v in aws_acm_certificate.cert : k => v.domain_name }
}

output "certificate_statuses" {
  description = "Map de nombre_clave → estado (PENDING_VALIDATION | ISSUED | INACTIVE)"
  value       = { for k, v in aws_acm_certificate.cert : k => v.status }
}

output "validation_record_fqdns" {
  description = "Map de nombre_clave → FQDNs de los CNAME de validación creados en Route53"
  value = {
    for cert_key in keys(local.dns_validated) :
    cert_key => [
      for dvo in aws_acm_certificate.cert[cert_key].domain_validation_options :
      try(aws_route53_record.validation["${cert_key}-${dvo.domain_name}"].fqdn, "")
    ]
  }
}
