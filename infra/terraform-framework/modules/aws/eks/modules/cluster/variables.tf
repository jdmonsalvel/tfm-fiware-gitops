variable "tags" {
  type    = map(string)
  default = {}
}

variable "cluster_name" {
  type = string
}

variable "cluster_role_arn" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.33"
}

variable "authentication_mode" {
  type    = string
  default = "API_AND_CONFIG_MAP"
}

variable "enable_cluster_creator_admin" {
  type    = bool
  default = false
}

variable "enabled_log_types" {
  type    = list(string)
  default = ["api", "audit", "authenticator"]
}

variable "kms_key_arn" {
  type    = string
  default = null
}

variable "kms_create_key" {
  type    = bool
  default = false
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "bootstrap_self_managed_addons" {
  type    = bool
  default = false
}

variable "upgrade_policy" {
  type    = string
  default = "STANDARD"
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "control_plane_subnet_ids" {
  type    = list(string)
  default = null
}

variable "endpoint_public_access" {
  type    = bool
  default = false
}

variable "endpoint_private_access" {
  type    = bool
  default = true
}

variable "public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "cluster_security_group_additional_rules" {
  type = map(object({
    description                   = string
    protocol                      = string
    from_port                     = number
    to_port                       = number
    type                          = string
    source_cluster_security_group = optional(bool, false)
    cidr_blocks                   = optional(list(string), [])
    ipv6_cidr_blocks              = optional(list(string), [])
    source_security_group_id      = optional(string, null)
  }))
  default = {}
}

variable "addons" {
  description = "Configuración de addons EKS managed (coredns, vpc-cni, kube-proxy, ebs-csi)"
  type = object({
    coredns    = optional(bool, true)
    kube_proxy = optional(bool, true)
    vpc_cni    = optional(bool, true)
    ebs_csi    = optional(bool, true)
  })
  default = {}
}

variable "cluster_tags" {
  type    = map(string)
  default = {}
}

