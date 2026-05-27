variable "name_prefix" {
  type    = string
  default = null
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "security_groups" {
  type    = map(string)
  default = {}
}
variable "environment" {
  type = string
}
variable "project" {
  type = string
}

variable "subnets" {
  type    = map(string)
  default = {}
}

variable "keypairs" {
  type    = map(string)
  default = {}
}


variable "instances" {
  description = "Mapa de configuraciones para las instancias"
  type = map(object({
    name                    = string
    ami                     = string
    instance_type           = string
    security_groups         = optional(list(string))
    sql_licence             = optional(bool, false)
    virtual_ips             = optional(list(string), [])
    subnet_type             = optional(string)
    subnet_name             = optional(string)
    az                      = optional(string)
    subnet_id               = optional(string, null)
    key_pair                = optional(string)
    security_group_name     = optional(string)
    user_data               = optional(string)
    service_ip              = optional(string)
    management_ip           = optional(string)
    volume_size             = optional(number)
    volume_type             = optional(string, "gp3")
    iops                    = optional(number)
    schedule                = optional(string)
    imdsv2_required         = optional(bool, true)
    disable_api_termination = optional(bool, false)
    tags                    = optional(map(string))
    opt_disk                = optional(number)
    swap_disk               = optional(number)
    tempdb_disk             = optional(number)
    templog_disk            = optional(number)
    paging_disk             = optional(number)
    data_disk               = optional(number)
    logs_disk               = optional(number)
    backups_disk            = optional(number)
    app_disk                = optional(number)
    applog_disk             = optional(number)
    public                  = optional(bool, false)
  }))
  default = {}
}
