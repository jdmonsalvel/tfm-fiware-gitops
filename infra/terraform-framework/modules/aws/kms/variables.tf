variable "kms_keys" {
  type = map(object({
    description         = optional(string, "")
    enable_key_rotation = optional(bool, true)
    tags                = optional(map(string), {})
    policy              = optional(string, null)
  }))
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}