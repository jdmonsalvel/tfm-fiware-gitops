output "secret_arns" {
  description = "Map de nombre_clave → ARN del secreto"
  value       = { for k, v in aws_secretsmanager_secret.secret : k => v.arn }
}

output "secret_ids" {
  description = "Map de nombre_clave → nombre completo del secreto (path)"
  value       = { for k, v in aws_secretsmanager_secret.secret : k => v.name }
}

output "secret_version_ids" {
  description = "Map de nombre_clave → version ID del secreto"
  value       = { for k, v in aws_secretsmanager_secret_version.secret : k => v.version_id }
}
