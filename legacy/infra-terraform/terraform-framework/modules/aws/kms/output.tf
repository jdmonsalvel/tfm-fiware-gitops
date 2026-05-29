output "kms_key_ids" {
  description = "Map of KMS key name to key ID"
  value       = { for k, v in aws_kms_key.key : k => v.key_id }
}

output "kms_key_arns" {
  description = "Map of KMS key name to key ARN"
  value       = { for k, v in aws_kms_key.key : k => v.arn }
}

output "kms_alias_arns" {
  description = "Map of KMS key name to alias ARN (alias/<key>)"
  value       = { for k, v in aws_kms_alias.alias : k => v.arn }
}