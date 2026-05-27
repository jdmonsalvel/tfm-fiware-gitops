variable "tags" {
  type    = map(string)
  default = {}
}

variable "cluster_name" {
  type = string
}

variable "karpenter_enabled" {
  type    = bool
  default = false
}
