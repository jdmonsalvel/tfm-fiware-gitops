output "repository_urls" {
  description = "Map de nombre_clave → URL del repositorio ECR"
  value       = { for k, v in aws_ecr_repository.repo : k => v.repository_url }
}

output "repository_arns" {
  description = "Map de nombre_clave → ARN del repositorio ECR"
  value       = { for k, v in aws_ecr_repository.repo : k => v.arn }
}

output "registry_id" {
  description = "ID del registry ECR (= account_id)"
  value       = length(aws_ecr_repository.repo) > 0 ? values(aws_ecr_repository.repo)[0].registry_id : data.aws_caller_identity.current.account_id
}
