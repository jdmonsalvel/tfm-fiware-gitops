output "transit_gateway_route_table_ids" {
  description = "Map of Transit Gateway Route Table name to Route Table ID"
  value       = { for k, v in aws_ec2_transit_gateway_route_table.transit_gw_route_table : k => v.id }
}