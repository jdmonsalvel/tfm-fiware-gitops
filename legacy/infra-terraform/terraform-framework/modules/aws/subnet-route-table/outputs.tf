output "route_table_ids" {
  description = "Map of route table name to route table ID"
  value       = { for k, rt in aws_route_table.route_table : k => rt.id }
}