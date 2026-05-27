resource "aws_ec2_transit_gateway" "transit-gw" {
  for_each = var.transit_gateways

  description                     = each.value.description
  amazon_side_asn                 = each.value.amazon_side_asn
  auto_accept_shared_attachments  = each.value.auto_accept_shared_attachments
  default_route_table_association = each.value.default_route_table_association
  default_route_table_propagation = each.value.default_route_table_propagation
  vpn_ecmp_support                = each.value.vpn_ecmp_support
  dns_support                     = each.value.dns_support
  multicast_support               = each.value.multicast_support
  tags = merge(
    var.tags,
    {
      Name = "${each.value.name}"
    }
  )
}

