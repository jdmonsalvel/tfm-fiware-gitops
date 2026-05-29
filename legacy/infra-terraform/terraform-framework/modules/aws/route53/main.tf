# ──────────────────────────────────────────────────────────────────────────────
# ZONAS PÚBLICAS
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_route53_zone" "public" {
  for_each = local.public_zones

  name              = each.value.name
  comment           = each.value.comment
  delegation_set_id = each.value.delegation_set_id
  force_destroy     = each.value.force_destroy

  tags = merge(var.tags, each.value.tags, { Name = each.value.name })
}

# ──────────────────────────────────────────────────────────────────────────────
# ZONAS PRIVADAS
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_route53_zone" "private" {
  for_each = local.private_zones

  name          = each.value.name
  comment       = each.value.comment
  force_destroy = each.value.force_destroy

  dynamic "vpc" {
    for_each = each.value.vpc_ids
    content {
      vpc_id = vpc.value
    }
  }

  tags = merge(var.tags, each.value.tags, { Name = each.value.name })
}

# ──────────────────────────────────────────────────────────────────────────────
# RECORDS DNS
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_route53_record" "record" {
  for_each = var.route53_records

  zone_id = local.all_zone_ids[each.value.zone_key]
  name    = each.value.name
  type    = each.value.type

  # ttl y records solo en records simples (no alias)
  ttl     = each.value.alias == null ? each.value.ttl : null
  records = each.value.alias == null ? each.value.records : null

  dynamic "alias" {
    for_each = each.value.alias != null ? [each.value.alias] : []
    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = alias.value.evaluate_target_health
    }
  }

  health_check_id = each.value.health_check_id
  set_identifier  = each.value.set_identifier

  dynamic "weighted_routing_policy" {
    for_each = each.value.weighted_routing != null ? [each.value.weighted_routing] : []
    content {
      weight = weighted_routing_policy.value.weight
    }
  }

  dynamic "latency_routing_policy" {
    for_each = each.value.latency_routing != null ? [each.value.latency_routing] : []
    content {
      region = latency_routing_policy.value.region
    }
  }

  dynamic "failover_routing_policy" {
    for_each = each.value.failover_routing != null ? [each.value.failover_routing] : []
    content {
      type = failover_routing_policy.value.type
    }
  }
}
