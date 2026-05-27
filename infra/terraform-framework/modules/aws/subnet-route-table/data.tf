data "aws_ec2_transit_gateway_attachment" "tgw_attachment" {
  for_each = {
    for k, v in var.transit_gateway_attachment_ids : k => v
    if var.transit_gateway_id == null
  }

  transit_gateway_attachment_id = each.value
}

