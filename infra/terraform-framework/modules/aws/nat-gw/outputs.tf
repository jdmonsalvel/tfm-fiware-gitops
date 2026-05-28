output "nat_gateway_ids" {
  description = "Map of NAT Gateway name to NAT Gateway ID"
  value       = { for k, v in aws_nat_gateway.nat_gateway : k => v.id }
}

output "nat_gateway_public_ips" {
  description = "Map of NAT Gateway name to public IP"
  value       = { for k, v in aws_nat_gateway.nat_gateway : k => v.public_ip }
}

output "nat_gateway_eip_ids" {
  description = "Map of NAT Gateway name to EIP allocation ID (only for self-created EIPs)"
  value       = { for k, v in aws_eip.elastic_ip : k => v.id }
}