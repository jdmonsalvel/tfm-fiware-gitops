variable "vpc_ids" {
  type    = map(string)
  default = {}
}
variable "subnet_ids" {
  type    = map(string)
  default = {}
}
variable "transit_gateway_attachment_ids" {
  type    = map(string)
  default = {}
}
variable "internet_gateway_ids" {
  type    = map(string)
  default = {}
}
variable "nat_gateway_ids" {
  type    = map(string)
  default = {}
}

variable "regional_nat_gateway_ids" {
  type    = map(string)
  default = {}
}
variable "transit_gateway_ids" {
  type    = map(string)
  default = {}
}

variable "transit_gateway_id" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
variable "subnet_route_tables" {
  type = map(object({
    name          = string
    vpc_name      = string
    subnets_names = list(string)
    tags          = optional(map(string))
    routes = map(object({
      destiny = string
      target  = string
    }))
  }))
  default = {}
}