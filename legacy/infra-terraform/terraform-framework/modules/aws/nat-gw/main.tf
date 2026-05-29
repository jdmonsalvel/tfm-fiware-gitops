resource "aws_eip" "elastic_ip" {
  for_each = { for k, v in local.nat_gateways_config : k => v if v.eip_id == null }
  domain   = "vpc"
  tags = merge(
    var.tags,
    {
      Name = "${each.value.name}"
    }
  )
}

resource "aws_nat_gateway" "nat_gateway" {
  for_each = local.nat_gateways_config

  subnet_id         = var.subnet_ids[each.value.subnet_name]
  allocation_id     = each.value.eip_id != null ? each.value.eip_id : aws_eip.elastic_ip[each.key].id
  connectivity_type = each.value.connectivity_type
  private_ip        = lookup(each.value, "primary_private_ipv4", null)
  tags = merge(
    var.tags,
    {
      Name = "${each.value.name}"
    }
  )
}
