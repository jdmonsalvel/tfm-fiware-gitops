locals {
  nat_gateways_config = {
    for k, v in var.nat_gateways : k => merge(v, {
      eip_id    = lookup(v, "eip_allocation_id", null),
      subnet_id = var.subnet_ids[v.subnet_name]
    })
  }
}