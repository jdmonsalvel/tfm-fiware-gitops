variable "rds_instances" {
  description = "Map of RDS instance configurations"
  type = map(object({
    name                            = string
    engine                          = string
    engine_version                  = string
    instance_class                  = string
    db_name                         = optional(string)
    username                        = string
    manage_master_user_password     = optional(bool, true)
    multi_az                        = optional(bool, false)
    allocated_storage               = optional(number, 20)
    max_allocated_storage           = optional(number, 100)
    storage_type                    = optional(string, "gp3")
    storage_encrypted               = optional(bool, true)
    backup_retention_period         = optional(number, 7)
    deletion_protection             = optional(bool, false)
    skip_final_snapshot             = optional(bool, true)
    security_group_names            = list(string)
    parameter_group_name            = optional(string)
    option_group_name               = optional(string)
    maintenance_window              = optional(string, "Mon:03:00-Mon:04:00")
    backup_window                   = optional(string, "02:00-03:00")
    publicly_accessible             = optional(bool, false)
    iam_database_authentication     = optional(bool, false)
    performance_insights_enabled    = optional(bool, false)
    enabled_cloudwatch_logs_exports = optional(list(string), [])
    auto_minor_version_upgrade      = optional(bool, true)
    apply_immediately               = optional(bool, false)
    tags                            = optional(map(string), {})
  }))
  default = {}
}

variable "db_subnet_group_name" {
  description = "Name of the DB subnet group (from db-subnet-group module output)"
  type        = string
}

variable "security_group_ids" {
  description = "Map of security group name to ID (from security-group module output)"
  type        = map(string)
  default     = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
