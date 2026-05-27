
variable "tags" {
  type    = map(string)
  default = {}
}

variable "transit_gateways" {
  description = "Map of transit gateways to create"
  type = map(object({
    name                            = string
    description                     = optional(string, null)
    amazon_side_asn                 = optional(number, 64512)
    auto_accept_shared_attachments  = optional(string, "enable")
    default_route_table_association = optional(string, "disable")
    default_route_table_propagation = optional(string, "disable")
    vpn_ecmp_support                = optional(string, "enable")
    dns_support                     = optional(string, "enable")
    multicast_support               = optional(string, "disable")
    tags                            = optional(map(string))
  }))
  default = {}
}
