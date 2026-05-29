output "transit_gateway_ids" {
  description = "Map of Transit Gateway name to Transit Gateway ID"
  value       = { for k, v in aws_ec2_transit_gateway.transit-gw : k => v.id }
}

output "transit_gateway_arns" {
  description = "Map of Transit Gateway name to Transit Gateway ARN"
  value       = { for k, v in aws_ec2_transit_gateway.transit-gw : k => v.arn }
}
