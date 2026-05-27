resource "aws_vpc_dhcp_options" "dhcp" {
  for_each = var.dhcp_option_sets

  domain_name_servers = each.value.domain-name-servers != null ? each.value.domain-name-servers : each.value.domain_name == "compute.internal" ? ["AmazonProvidedDNS"] : local.dhcp_dns
  domain_name         = each.value.domain_name == "compute.internal" ? "${var.region}.${each.value.domain_name}" : each.value.domain_name
  tags = merge(
    var.tags,
    {
      Name = "${each.value.name}"
    }
  )
  # lifecycle {
  #   ignore_changes = [ 
  #     domain_name,
  #     domain_name_servers
  #   ]
  # }
}

resource "aws_vpc_dhcp_options_association" "dhcp" {
  for_each        = var.dhcp_option_sets
  vpc_id          = var.vpc_ids[each.value.vpc_name]
  dhcp_options_id = aws_vpc_dhcp_options.dhcp[each.key].id
}
