variable "tags" {
  type    = map(string)
  default = {}
}

variable "cluster_name" {
  type = string
}

variable "oidc_issuer_url" {
  description = "URL completa del OIDC issuer (ej: https://oidc.eks.eu-west-1.amazonaws.com/id/XXXX)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN del OIDC provider creado en el módulo cluster"
  type        = string
}

variable "addons" {
  type = object({
    aws_load_balancer_controller = optional(bool, true)
    cert_manager                 = optional(bool, true)
    external_secrets             = optional(bool, true)
    external_dns                 = optional(bool, false)
    velero                       = optional(bool, false)
    ebs_csi                      = optional(bool, true)
    karpenter                    = optional(bool, false)
    monitoring                   = optional(bool, false)
  })
  default = {}
}

variable "karpenter_enabled" {
  type    = bool
  default = false
}

variable "monitoring_bucket_arn" {
  description = "ARN del bucket S3 de monitoring (para permisos de Loki/Prometheus)"
  type        = string
  default     = ""
}

variable "karpenter_queue_arn" {
  description = "ARN de la SQS queue de Karpenter (creada en el módulo iam)"
  type        = string
  default     = ""
}
