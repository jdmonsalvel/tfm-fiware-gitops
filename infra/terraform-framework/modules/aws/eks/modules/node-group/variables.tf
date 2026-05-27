variable "tags" {
  type    = map(string)
  default = {}
}

variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "cluster_ca" {
  type = string
}

variable "cluster_service_cidr" {
  type    = string
  default = "172.20.0.0/16"
}

variable "node_role_arn" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "cluster_tools_node_group" {
  type = object({
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
  })
  default = {}
}

variable "workload_node_groups" {
  type = map(object({
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
  }))
  default = {}
}
