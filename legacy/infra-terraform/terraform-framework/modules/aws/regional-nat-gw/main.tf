locals {
  # Solo crea EIP para public gateways sin EIP preexistente
  gateways_needing_eip = {
    for k, v in var.regional_nat_gateways : k => v
    if v.connectivity_type == "public" && v.eip_allocation_id == null
  }
}

resource "aws_eip" "regional" {
  for_each = local.gateways_needing_eip
  domain   = "vpc"
  tags = merge(
    var.tags,
    each.value.tags,
    { Name = "${each.value.name}-eip" }
  )
}

resource "aws_nat_gateway" "regional" {
  for_each = var.regional_nat_gateways

  connectivity_type = each.value.connectivity_type == "private" ? "private" : "regional"

  allocation_id = each.value.connectivity_type != "private" ? (
    each.value.eip_allocation_id != null
    ? each.value.eip_allocation_id
    : aws_eip.regional[each.key].id
  ) : null

  tags = merge(
    var.tags,
    each.value.tags,
    { Name = each.value.name }
  )
}
