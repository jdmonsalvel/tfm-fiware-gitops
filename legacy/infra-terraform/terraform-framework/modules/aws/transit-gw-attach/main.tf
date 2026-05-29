resource "aws_ec2_transit_gateway_vpc_attachment" "transit_gateway_attachment" {
  for_each = var.transit_gateway_attachments

  transit_gateway_id = var.transit_gateway_id != null ? var.transit_gateway_id : var.transit_gateway_ids[each.value.transit_gateway_name]
  vpc_id             = var.vpc_ids[each.value.vpc_name]
  subnet_ids         = [for subnet_name in each.value.subnet_names : var.subnet_ids[subnet_name]]
  tags = merge(
    var.tags,
    {
      Name = "${each.value.name}"
    }
  )
}
