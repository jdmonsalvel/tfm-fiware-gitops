output "subnet_ids" {
  description = "Map of subnet name to subnet ID"
  value       = { for k, s in aws_subnet.subnet : k => s.id }
}

output "db_subnet_ids" {
  description = "List of subnet IDs where db_subnet = true (used by db-subnet-group)"
  value = [
    for k, s in aws_subnet.subnet : s.id
    if try(var.subnets[k].db_subnet, false)
  ]
}

output "subnet_arns" {
  description = "Map of subnet name to subnet ARN"
  value       = { for k, s in aws_subnet.subnet : k => s.arn }
}