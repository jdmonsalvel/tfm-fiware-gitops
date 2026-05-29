variable "vpc_ids" {
  type = map(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "network_acls" {
  description = "Map of network ACLs with their rules"
  type = map(object({
    name     = string
    vpc_name = string
    tags     = optional(map(string))
    rules = map(object({
      rule_number = number
      type        = string
      protocol    = string
      rule_action = string
      cidr_block  = string
      from_port   = number
      to_port     = number
      icmp_type   = optional(number, -1)
      icmp_code   = optional(number, -1)
    }))
  }))
  default = {}
}