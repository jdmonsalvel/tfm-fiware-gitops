output "regional_nat_gateway_ids" {
  description = "Map of Regional NAT Gateway name to NAT Gateway ID"
  value       = { for k, v in aws_nat_gateway.regional : k => v.id }
}

output "regional_nat_gateway_public_ips" {
  description = "Map of Regional NAT Gateway name to public IP (solo gateways public)"
  value       = { for k, v in aws_nat_gateway.regional : k => v.public_ip }
}

output "regional_nat_gateway_eip_ids" {
  description = "Map of Regional NAT Gateway name to EIP allocation ID (solo EIPs creadas por este módulo)"
  value       = { for k, v in aws_eip.regional : k => v.id }
}
