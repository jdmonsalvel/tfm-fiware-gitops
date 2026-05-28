variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "cluster_ca" {
  type = string
}

variable "cluster_region" {
  type    = string
  default = "eu-west-1"
}

variable "cluster_version" {
  type    = string
  default = ""
}

variable "vpc_id" {
  type = string
}

variable "assume_role_arn" {
  type    = string
  default = ""
}

variable "irsa_roles" {
  description = "ARNs de los IRSA roles por addon"
  type = object({
    aws_load_balancer_controller = optional(string, "")
    cert_manager                 = optional(string, "")
    external_secrets             = optional(string, "")
    external_dns                 = optional(string, "")
    velero                       = optional(string, "")
    ebs_csi                      = optional(string, "")
    karpenter                    = optional(string, "")
    monitoring                   = optional(string, "")
  })
  default = {}
}

variable "addons" {
  type = object({
    coredns                      = optional(bool, true)
    kube_proxy                   = optional(bool, true)
    vpc_cni                      = optional(bool, true)
    ebs_csi                      = optional(bool, true)
    aws_load_balancer_controller = optional(bool, true)
    cert_manager                 = optional(bool, true)
    external_secrets             = optional(bool, true)
    external_dns                 = optional(bool, false)
    metrics_server               = optional(bool, true)
    velero                       = optional(bool, false)
    istio                        = optional(bool, false)
    karpenter                    = optional(bool, false)
    keda                         = optional(bool, false)
    cluster_autoscaler           = optional(bool, false)
    reloader                     = optional(bool, false)
    helm_chart_versions          = optional(map(string), {})
  })
  default = {}
}

variable "helm_versions" {
  description = "Versiones finales de Helm charts (merge de defaults y overrides del usuario)"
  type        = map(string)
  default     = {}
}

variable "monitoring" {
  type = object({
    mode = optional(string, "disabled")
    storage = optional(object({
      s3_bucket_name = optional(string, null)
      retention_days = optional(number, 30)
      create_bucket  = optional(bool, true)
    }), {})
    centralized_config = optional(object({
      metrics = optional(object({
        enabled          = optional(bool, false)
        remote_write_url = optional(string, null)
        secret_ref       = optional(string, null)
      }), {})
      logs = optional(object({
        enabled    = optional(bool, false)
        endpoint   = optional(string, null)
        secret_ref = optional(string, null)
      }), {})
      traces = optional(object({
        enabled    = optional(bool, false)
        endpoint   = optional(string, null)
        secret_ref = optional(string, null)
      }), {})
      grafana = optional(object({
        enabled               = optional(bool, false)
        url                   = optional(string, null)
        datasource_secret_ref = optional(string, null)
      }), {})
    }), null)
  })
  default = {}
}

variable "monitoring_bucket" {
  description = "Nombre del bucket S3 para almacenamiento de monitoring"
  type        = string
  default     = ""
}

variable "karpenter_node_role_arn" {
  type    = string
  default = ""
}

variable "karpenter_queue_url" {
  type    = string
  default = ""
}

variable "backend_bucket" {
  description = "Bucket S3 del state del bootstrap — leído por bootstrap.sh, no usado internamente"
  type        = string
  default     = ""
}

variable "backend_region" {
  type    = string
  default = "eu-west-1"
}
