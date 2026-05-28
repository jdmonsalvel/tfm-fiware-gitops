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
variable "vpc_ids" {
  type    = map(string)
  default = {}
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "network_acl_ids" {
  type    = map(string)
  default = {}
}
variable "region" {
  type    = string
  default = null
}
variable "subnets" {
  type    = map(string)
  default = {}
}

variable "keypairs" {
  type    = map(string)
  default = {}
}

variable "autoscaling_groups" {
  description = "Mapa de configuraciones para múltiples ASG completos (ALB + LT + ASG)"
  type = map(object({
    name                      = string
    vpc_name                  = string
    instance_subnets          = list(string)
    alb_subnets               = list(string)
    alb_internal              = optional(bool, false)
    alb_security_groups       = optional(list(string), null)
    instances_security_groups = optional(list(string), null)
    instance_type             = string
    ami_id                    = string
    min_size                  = number
    max_size                  = number
    desired_capacity          = number
    key_pair                  = optional(string, null)
    certificate_arn           = optional(string, null)
    stickiness_type           = optional(string, null)
    stickiness_duration       = optional(number, 3600)
    app_cookie_name           = optional(string, null)
    policy_enabled            = optional(bool, false)
    user_data_base64          = optional(string, null)
    health_check_path         = optional(string, "/")
    listener_port_http        = optional(number, 80)
    imdsv2_required           = optional(bool, true)
    ebs_encrypted             = optional(bool, true)
    ebs_volume_size           = optional(number, 20)
    ebs_volume_type           = optional(string, "gp3")
    scale_up_adjustment       = optional(number, 1)
    scale_down_adjustment     = optional(number, -1)
    scale_up_threshold        = optional(number, 75)
    scale_down_threshold      = optional(number, 20)
    tags                      = optional(map(string), {})
  }))

  default = {}
}
