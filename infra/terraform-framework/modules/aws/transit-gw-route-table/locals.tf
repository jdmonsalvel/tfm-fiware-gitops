locals {
  routes = flatten([
    for rt_key, rt_value in var.transit_gateway_route_tables : [
      for route_key, route_value in rt_value.routes != null ? rt_value.routes : {} : {
        key        = "${rt_key}-${route_key}"
        rt_key     = rt_key
        cidr_block = route_value.destiny
        target     = lookup(var.transit_gateway_attachment_ids, route_value.target, null)
      }
    ]
  ])
}