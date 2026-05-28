output "vpc_ids" {
  description = "Map of VPC name to VPC ID"
  value       = { for k, v in aws_vpc.vpc : k => v.id }
}

output "vpc_arns" {
  description = "Map of VPC name to VPC ARN"
  value       = { for k, v in aws_vpc.vpc : k => v.arn }
}

output "vpc_cidr_blocks" {
  description = "Map of VPC name to CIDR block"
  value       = { for k, v in aws_vpc.vpc : k => v.cidr_block }
}