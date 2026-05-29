resource "aws_security_group" "security_group" {
  for_each = var.security_groups

  name        = each.value.name
  description = each.value.description
  vpc_id = (
    each.value.vpc_name == null || each.value.vpc_name == "" ? (
      length(var.vpc_ids) > 0 ? values(var.vpc_ids)[0] : null
      ) : (
      try(var.vpc_ids[each.value.vpc_name], null)
    )
  )
  tags = merge(
    var.tags,
    {
      Name = "${each.value.name}"
    }
  )
  dynamic "ingress" {
    for_each = each.value.ingress
    content {
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      cidr_blocks     = ingress.value.cidr_blocks
      security_groups = length(ingress.value.source_sg_ids) > 0 ? toset(ingress.value.source_sg_ids) : null
      self            = ingress.value.self
      description     = ingress.value.description
    }
  }

  dynamic "egress" {
    for_each = each.value.egress
    content {
      from_port       = egress.value.from_port
      to_port         = egress.value.to_port
      protocol        = egress.value.protocol
      cidr_blocks     = egress.value.cidr_blocks
      security_groups = length(egress.value.source_sg_ids) > 0 ? toset(egress.value.source_sg_ids) : null
      self            = egress.value.self
      description     = egress.value.description
    }
  }
}
