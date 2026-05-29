resource "aws_ec2_transit_gateway_route_table" "transit_gw_route_table" {
  for_each = var.transit_gateway_route_tables

  transit_gateway_id = var.transit_gateway_ids[each.value.transit_gateway_name]

  tags = merge(
    var.tags,
    {
      Name = "${each.value.name}"
    }
  )
}

resource "aws_ec2_transit_gateway_route" "transit_gw_route" {
  for_each = { for route in local.routes : route.key => route }

  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.transit_gw_route_table[each.value.rt_key].id
  destination_cidr_block         = each.value.cidr_block
  transit_gateway_attachment_id  = each.value.target
  depends_on                     = [aws_ec2_transit_gateway_route_table.transit_gw_route_table]
}