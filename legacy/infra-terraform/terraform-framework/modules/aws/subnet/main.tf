resource "aws_subnet" "subnet" {
  for_each = var.subnets

  vpc_id                  = var.vpc_ids[each.value.vpc_name]
  cidr_block              = each.value.cidr_block
  availability_zone       = "${var.region}${each.value.availability_zone}"
  map_public_ip_on_launch = each.value.ip_public_auto ? true : false
  tags = merge(
    var.tags,
    {
      Name = "${each.value.name}"
    }
  )
}

resource "aws_network_acl_association" "subnet_network_acl" {
  for_each = { for k, v in var.subnets : k => v if v.network_acl_name != null }

  subnet_id      = aws_subnet.subnet[each.key].id
  network_acl_id = var.network_acl_ids[each.value.network_acl_name]
}
