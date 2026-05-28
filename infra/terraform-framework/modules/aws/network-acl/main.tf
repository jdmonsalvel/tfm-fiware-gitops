resource "aws_network_acl" "network_acl" {
  for_each = { for acl_name, acl in var.network_acls : acl_name => acl }

  vpc_id = var.vpc_ids[each.value.vpc_name]

  tags = merge(
    var.tags,
    {
      Name = "${each.value.name}"
    }
  )
}

resource "aws_network_acl_rule" "network_acl_rule" {
  for_each = { for idx, rule in local.acl_rules : idx => rule }

  network_acl_id = aws_network_acl.network_acl[each.value.network_acl_name].id
  rule_number    = each.value.rule_number
  egress         = each.value.egress
  protocol       = each.value.protocol
  rule_action    = each.value.rule_action
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
  icmp_type      = each.value.protocol == "icmp" || each.value.protocol == "1" ? each.value.icmp_type : null
  icmp_code      = each.value.protocol == "icmp" || each.value.protocol == "1" ? each.value.icmp_code : null
}
