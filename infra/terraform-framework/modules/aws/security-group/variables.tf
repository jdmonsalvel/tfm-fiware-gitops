variable "tags" {
  type    = map(string)
  default = {}
}
variable "vpc_ids" {
  type    = map(string)
  default = {}
}
variable "existin_vpc_name" {
  type    = string
  default = null
}
variable "security_groups" {
  description = "Map of security group definitions"
  type = map(object({
    name        = string
    description = optional(string)
    vpc_name    = optional(string)
    ingress = optional(map(object({
      from_port     = number
      to_port       = number
      protocol      = string
      cidr_blocks   = optional(list(string), [])
      source_sg_ids = optional(list(string), [])
      self          = optional(bool, false)
      description   = optional(string)
    })), {})
    egress = optional(map(object({
      from_port     = number
      to_port       = number
      protocol      = string
      cidr_blocks   = optional(list(string), [])
      source_sg_ids = optional(list(string), [])
      self          = optional(bool, false)
      description   = optional(string)
    })), {})
    tags = optional(map(string))
  }))
  default = {}
}
