output "db_subnet_group_name" {
  description = "Name of the DB subnet group (used by RDS and DocumentDB)"
  value       = length(aws_db_subnet_group.db_subnet_group) > 0 ? aws_db_subnet_group.db_subnet_group[0].name : null
}

output "db_subnet_group_arn" {
  description = "ARN of the DB subnet group"
  value       = length(aws_db_subnet_group.db_subnet_group) > 0 ? aws_db_subnet_group.db_subnet_group[0].arn : null
}
