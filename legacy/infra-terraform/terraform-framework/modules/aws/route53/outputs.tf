output "zone_ids" {
  description = "Map de nombre_clave → ID de zona Route53"
  value = merge(
    { for k, v in aws_route53_zone.public : k => v.zone_id },
    { for k, v in aws_route53_zone.private : k => v.zone_id }
  )
}

output "zone_arns" {
  description = "Map de nombre_clave → ARN de zona Route53"
  value = merge(
    { for k, v in aws_route53_zone.public : k => v.arn },
    { for k, v in aws_route53_zone.private : k => v.arn }
  )
}

output "name_servers" {
  description = "Map de nombre_clave → name servers de la zona (solo zonas públicas)"
  value       = { for k, v in aws_route53_zone.public : k => v.name_servers }
}

output "record_fqdns" {
  description = "Map de nombre_clave → FQDN del record"
  value       = { for k, v in aws_route53_record.record : k => v.fqdn }
}
