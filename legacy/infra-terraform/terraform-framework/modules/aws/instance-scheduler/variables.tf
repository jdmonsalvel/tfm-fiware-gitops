variable "tags" {
  type    = map(string)
  default = {}
}

variable "instance_schedulers" {
  type = map(object({
    # ── Modo ────────────────────────────────────────────────────────────────────
    role = string # "hub" | "spoke"

    # ── CloudFormation — parámetros del stack hub ───────────────────────────────
    namespace  = optional(string, "default")
    tag_name   = optional(string, "Schedule")

    default_timezone   = optional(string, "UTC")
    regions            = optional(list(string), []) # [] = región del stack
    scheduler_frequency = optional(number, 5)       # minutos entre ejecuciones

    scheduling_active              = optional(bool, true)
    create_rds_snapshot            = optional(bool, false)
    enable_ssm_maintenance_windows = optional(bool, false)
    enable_informational_tagging   = optional(bool, true)
    ops_monitoring                 = optional(string, "Enabled") # "Enabled" | "Disabled"
    retain_data_and_logs           = optional(string, "Enabled") # "Enabled" | "Disabled"

    memory_size              = optional(number, 512)
    orchestrator_memory_size = optional(number, 512)
    log_retention_days       = optional(number, 30)
    trace                    = optional(bool, false)

    # ── Periods — ventanas horarias ─────────────────────────────────────────────
    periods = optional(map(object({
      begintime = string
      endtime   = string
      weekdays  = optional(list(string), [])
      months    = optional(list(string), [])
      monthdays = optional(list(string), [])
    })), {})

    # ── Schedules — agrupan periods y asocian recursos ─────────────────────────
    schedules = optional(map(object({
      periods            = list(string)           # claves del mapa periods
      timezone           = optional(string, null) # null = default_timezone del hub
      description        = optional(string, "")
      stop_new_instances = optional(bool, true)

      compute_resources = optional(object({
        ec2 = optional(list(string), [])
        rds = optional(list(string), [])
      }), { ec2 = [], rds = [] })
    })), {})

    # ── Spoke — cuenta gestionada (cross-account) ───────────────────────────────
    hub_account_id = optional(string, null)

    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.instance_schedulers : contains(["hub", "spoke"], v.role)
    ])
    error_message = "El campo 'role' debe ser 'hub' o 'spoke'."
  }

  validation {
    condition = alltrue([
      for k, v in var.instance_schedulers :
      v.role == "hub" || v.hub_account_id != null
    ])
    error_message = "Los schedulers en modo 'spoke' requieren 'hub_account_id'."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.instance_schedulers : [
        for sk, s in coalesce(v.schedules, {}) : [
          for p in s.periods : contains(keys(coalesce(v.periods, {})), p)
        ]
      ]
    ]))
    error_message = "Cada schedule.periods debe referenciar una clave válida del mapa 'periods'."
  }
}
