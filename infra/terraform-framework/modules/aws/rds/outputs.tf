output "rds_instance_ids" {
  description = "Map of RDS instance name to instance ID"
  value       = { for k, v in aws_db_instance.rds : k => v.id }
}

output "rds_instance_endpoints" {
  description = "Map of RDS instance name to connection endpoint"
  value       = { for k, v in aws_db_instance.rds : k => v.endpoint }
}

output "rds_instance_arns" {
  description = "Map of RDS instance name to ARN"
  value       = { for k, v in aws_db_instance.rds : k => v.arn }
}
