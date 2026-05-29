output "security_group_ids" {
  description = "Map of security group name to security group ID"
  value       = { for k, v in aws_security_group.security_group : k => v.id }
}

output "security_group_arns" {
  description = "Map of security group name to ARN"
  value       = { for k, v in aws_security_group.security_group : k => v.arn }
}
