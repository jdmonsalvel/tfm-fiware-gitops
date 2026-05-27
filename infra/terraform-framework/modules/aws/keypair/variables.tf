variable "name_prefix" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
variable "region" {
  type    = string
  default = "eu-central-1"
}
variable "keypairs" {
  description = "Map of keypair definitions"
  type = map(object({
    name            = string
    algorithm       = optional(string, "RSA")
    rsa_bits        = optional(number, 4096)
    ssm_path_prefix = optional(string)
    kms_key_id      = optional(string)
    tags            = optional(map(string), {})
  }))
  default = {}
}

variable "environment" {
  type = string
}

