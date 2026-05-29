

variable "tags" {
  type    = map(string)
  default = {}
}
variable "transit_gateway_ids" {
  type    = map(string)
  default = {}
}
variable "transit_gateway_attachment_ids" {
  type    = map(string)
  default = {}
}
variable "transit_gateway_route_tables" {
  description = "Map of transit gateway route tables to create"
  type = map(object({
    name                 = string
    transit_gateway_name = string
    tags                 = optional(map(string))
    routes = optional(map(object({
      destiny = string
      target  = string
    })))
  }))
  default = {}
}