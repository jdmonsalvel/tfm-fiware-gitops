output "network_acl_ids" {
  description = "Map of network ACL name to network ACL ID"
  value       = { for k, v in aws_network_acl.network_acl : k => v.id }
}