output "dhcp_option_set_ids" {
  description = "Map of DHCP option set name to DHCP option set ID"
  value       = { for k, v in aws_vpc_dhcp_options.dhcp : k => v.id }
}
