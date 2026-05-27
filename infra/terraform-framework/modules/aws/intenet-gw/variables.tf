variable "vpc_ids" {
  type = map(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
variable "internet_gateways" {
  type = map(object({
    name     = string
    vpc_name = string
    tags     = optional(map(string))
  }))
}