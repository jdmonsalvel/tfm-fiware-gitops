output "internet_gateway_ids" {
  description = "Map of Internet Gateway name to Internet Gateway ID"
  value       = { for k, v in aws_internet_gateway.internet_gateway : k => v.id }
}

output "internet_gateway_arns" {
  description = "Map of Internet Gateway name to ARN"
  value       = { for k, v in aws_internet_gateway.internet_gateway : k => v.arn }
}