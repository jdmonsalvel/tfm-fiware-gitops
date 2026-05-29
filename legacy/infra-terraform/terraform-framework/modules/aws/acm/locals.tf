locals {
  # Certificados con DNS validation y zona Route53 conocida → el módulo crea los CNAME
  dns_validated = {
    for k, v in var.acm_certificates : k => v
    if v.validation_method == "DNS" && v.zone_key != null
  }

  # Aplanar domain_validation_options de cada certificado validado automáticamente.
  # La clave combina cert_key + domain para que múltiples SANs en el mismo cert
  # generen records distintos sin colisión.
  validation_records = {
    for combo in flatten([
      for cert_key, cert in local.dns_validated : [
        for dvo in aws_acm_certificate.cert[cert_key].domain_validation_options : {
          key          = "${cert_key}-${dvo.domain_name}"
          cert_key     = cert_key
          zone_key     = cert.zone_key
          record_name  = dvo.resource_record_name
          record_type  = dvo.resource_record_type
          record_value = dvo.resource_record_value
        }
      ]
    ]) : combo.key => combo
  }
}
