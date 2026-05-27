variable "subnet_ids" {
  type = map(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
variable "region" {
  type = string
}
variable "nat_gateways" {
  type = map(object({
    name                 = string
    subnet_name          = string
    connectivity_type    = string
    eip_allocation_id    = optional(string)
    primary_private_ipv4 = optional(string)
    tags                 = optional(map(string))
  }))
}
