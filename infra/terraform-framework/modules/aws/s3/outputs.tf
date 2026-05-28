output "bucket_ids" {
  description = "Map de nombre_clave → bucket id (=nombre del bucket)"
  value       = { for k, v in aws_s3_bucket.bucket : k => v.id }
}

output "bucket_arns" {
  description = "Map de nombre_clave → bucket ARN"
  value       = { for k, v in aws_s3_bucket.bucket : k => v.arn }
}

output "bucket_domain_names" {
  description = "Map de nombre_clave → domain name regional del bucket"
  value       = { for k, v in aws_s3_bucket.bucket : k => v.bucket_regional_domain_name }
}

output "website_endpoints" {
  description = "Map de nombre_clave → endpoint de website estático (solo buckets con website habilitado)"
  value       = { for k, v in aws_s3_bucket_website_configuration.bucket : k => v.website_endpoint }
}
