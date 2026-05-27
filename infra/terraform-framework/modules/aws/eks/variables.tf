variable "tags" {
  description = "Tags globales heredados del wrapper raíz"
  type        = map(string)
  default     = {}
}

variable "backend_bucket" {
  description = "Bucket S3 donde se almacena el state del bootstrap de addons"
  type        = string
}

variable "backend_region" {
  description = "Región del bucket S3 de backend"
  type        = string
  default     = "eu-west-1"
}

variable "eks" {
  description = "Mapa de configuración de clusters EKS"
  type = map(object({

    account = optional(object({
      account_id      = optional(string, null)
      region          = optional(string, null)
      assume_role_arn = optional(string, null)
    }), {})

    network = object({
      vpc_id                   = string
      subnet_ids               = list(string)
      control_plane_subnet_ids = optional(list(string), null)
      endpoint_public_access   = optional(bool, false)
      endpoint_private_access  = optional(bool, true)
      public_access_cidrs      = optional(list(string), ["0.0.0.0/0"])
      cluster_security_group_additional_rules = optional(map(object({
        description                   = string
        protocol                      = string
        from_port                     = number
        to_port                       = number
        type                          = string
        source_cluster_security_group = optional(bool, false)
        cidr_blocks                   = optional(list(string), [])
        ipv6_cidr_blocks              = optional(list(string), [])
        source_security_group_id      = optional(string, null)
      })), {})
    })

    cluster = optional(object({
      kubernetes_version            = optional(string, "1.33")
      authentication_mode           = optional(string, "API_AND_CONFIG_MAP")
      enable_cluster_creator_admin  = optional(bool, false)
      enabled_log_types             = optional(list(string), ["api", "audit", "authenticator"])
      kms_key_arn                   = optional(string, null)
      kms_create_key                = optional(bool, false)
      deletion_protection           = optional(bool, true)
      bootstrap_self_managed_addons = optional(bool, false)
      upgrade_policy                = optional(string, "STANDARD")
      tags                          = optional(map(string), {})
    }), {})

    auth = optional(object({
      mode = optional(string, "access_entries")

      admins = optional(object({
        principal_arns      = optional(list(string), [])
        kubernetes_groups   = optional(list(string), ["platform-admins"])
        policy_associations = optional(list(string), ["arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"])
      }), {})

      developers = optional(object({
        principal_arns      = optional(list(string), [])
        kubernetes_groups   = optional(list(string), ["platform-developers"])
        policy_associations = optional(list(string), ["arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"])
      }), {})

      readonly = optional(object({
        principal_arns      = optional(list(string), [])
        kubernetes_groups   = optional(list(string), ["platform-readonly"])
        policy_associations = optional(list(string), ["arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"])
      }), {})

      additional_access_entries = optional(map(object({
        principal_arn       = string
        type                = optional(string, "STANDARD")
        kubernetes_groups   = optional(list(string), [])
        policy_associations = optional(list(string), [])
      })), {})
    }), {})

    addons = optional(object({
      coredns    = optional(bool, true)
      kube_proxy = optional(bool, true)
      vpc_cni    = optional(bool, true)
      ebs_csi    = optional(bool, true)

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

      helm_chart_versions = optional(map(string), {})
    }), {})

    monitoring = optional(object({
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
    }), {})

    compute = optional(object({
      cluster_tools_node_group = optional(object({
        capacity_type  = optional(string, "ON_DEMAND")
        instance_types = optional(list(string), ["m7i.large"])
        ami_id         = optional(string, null)
        ami_type       = optional(string, "AL2023_x86_64_STANDARD")
        min_size       = optional(number, 2)
        max_size       = optional(number, 4)
        desired_size   = optional(number, 2)
        disk_size      = optional(number, 50)
        disk_type      = optional(string, "gp3")
        labels         = optional(map(string), { "workload" = "cluster-tools" })
        taints = optional(list(object({
          key    = string
          value  = optional(string, null)
          effect = string
        })), [{ key = "CriticalAddonsOnly", value = "true", effect = "NO_SCHEDULE" }])
        additional_userdata = optional(string, null)
        tags                = optional(map(string), {})
      }), {})

      workload_node_groups = optional(map(object({
        capacity_type  = optional(string, "ON_DEMAND")
        instance_types = optional(list(string), ["m7i.xlarge"])
        ami_id         = optional(string, null)
        ami_type       = optional(string, "AL2023_x86_64_STANDARD")
        min_size       = optional(number, 1)
        max_size       = optional(number, 10)
        desired_size   = optional(number, 2)
        disk_size      = optional(number, 100)
        disk_type      = optional(string, "gp3")
        labels         = optional(map(string), {})
        taints = optional(list(object({
          key    = string
          value  = optional(string, null)
          effect = string
        })), [])
        additional_userdata = optional(string, null)
        tags                = optional(map(string), {})
      })), {})

      karpenter = optional(object({
        enabled                       = optional(bool, false)
        node_iam_role_name            = optional(string, null)
        create_instance_profile       = optional(bool, true)
        default_node_class_ami_family = optional(string, "AL2023")
        node_pools = optional(map(object({
          instance_families  = optional(list(string), ["m", "c", "r"])
          instance_sizes     = optional(list(string), ["large", "xlarge", "2xlarge"])
          capacity_type      = optional(list(string), ["on-demand"])
          availability_zones = optional(list(string), [])
          labels             = optional(map(string), {})
          taints = optional(list(object({
            key    = string
            value  = optional(string, null)
            effect = string
          })), [])
        })), {})
      }), {})

      fargate = optional(object({
        enabled = optional(bool, false)
        profiles = optional(map(object({
          selectors = list(object({
            namespace = string
            labels    = optional(map(string), {})
          }))
          tags = optional(map(string), {})
        })), {})
      }), {})
    }), {})

    tags = optional(map(string), {})
  }))

  default = {}

  validation {
    condition = alltrue([
      for k, v in var.eks :
      !(try(v.addons.karpenter, false) && try(v.addons.cluster_autoscaler, false))
    ])
    error_message = "karpenter y cluster_autoscaler son mutuamente excluyentes — no se pueden habilitar ambos en el mismo cluster."
  }

  validation {
    condition = alltrue([
      for k, v in var.eks :
      !(try(v.monitoring.mode, "disabled") == "centralized" && try(v.monitoring.centralized_config, null) == null)
    ])
    error_message = "monitoring.mode=centralized requiere que centralized_config esté definido."
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
