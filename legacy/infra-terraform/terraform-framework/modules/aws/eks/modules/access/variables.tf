variable "tags" {
  type    = map(string)
  default = {}
}

variable "cluster_name" {
  type = string
}

variable "authentication_mode" {
  type = string
}

variable "auth_mode" {
  description = "Modo de autenticación: access_entries | aws_auth | hybrid"
  type        = string
  default     = "access_entries"
}

variable "admins" {
  type = object({
    principal_arns      = optional(list(string), [])
    kubernetes_groups   = optional(list(string), ["platform-admins"])
    policy_associations = optional(list(string), ["arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"])
  })
  default = {}
}

variable "developers" {
  type = object({
    principal_arns      = optional(list(string), [])
    kubernetes_groups   = optional(list(string), ["platform-developers"])
    policy_associations = optional(list(string), ["arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"])
  })
  default = {}
}

variable "readonly" {
  type = object({
    principal_arns      = optional(list(string), [])
    kubernetes_groups   = optional(list(string), ["platform-readonly"])
    policy_associations = optional(list(string), ["arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"])
  })
  default = {}
}

variable "additional_access_entries" {
  type = map(object({
    principal_arn       = string
    type                = optional(string, "STANDARD")
    kubernetes_groups   = optional(list(string), [])
    policy_associations = optional(list(string), [])
  }))
  default = {}
}
