variable "vpc_ids" {
  type    = map(string)
  default = {}
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "network_acl_ids" {
  type    = map(string)
  default = {}
}
variable "region" {
  type    = string
  default = null
}
variable "subnets" {
  type = map(object({
    cidr_block        = string
    availability_zone = string
    tags              = optional(map(string))
    vpc_name          = string
    name              = string
    network_acl_name  = optional(string)
    ip_public_auto    = optional(bool, false)
    db_subnet         = optional(bool, false)
  }))
  default = {}
}
