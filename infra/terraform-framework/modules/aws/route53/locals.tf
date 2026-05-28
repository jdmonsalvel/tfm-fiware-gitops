locals {
  public_zones  = { for k, v in var.route53_zones : k => v if length(v.vpc_ids) == 0 }
  private_zones = { for k, v in var.route53_zones : k => v if length(v.vpc_ids) > 0 }

  all_zone_ids = merge(
    { for k, v in aws_route53_zone.public : k => v.zone_id },
    { for k, v in aws_route53_zone.private : k => v.zone_id }
  )
}
