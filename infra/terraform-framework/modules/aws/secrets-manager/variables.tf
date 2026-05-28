variable "tags" {
  type    = map(string)
  default = {}
}

variable "secrets_manager_secrets" {
  description = "Mapa de secretos en AWS Secrets Manager. El valor se genera aleatoriamente en el primer apply y no se sobreescribe si se actualiza manualmente."
  type = map(object({
    name        = string
    description = optional(string, "")

    # Si true, genera una password aleatoria de 32 chars alfanuméricos en el primer apply.
    # Si false, secret_string es obligatorio.
    generate_password = optional(bool, true)
    secret_string     = optional(string, null)

    # 0 = borrado inmediato (recomendado en lab). AWS cobra 7-30 días de retención si > 0.
    recovery_window_in_days = optional(number, 0)

    kms_key_id = optional(string, null)
    tags       = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.secrets_manager_secrets :
      v.generate_password == true || v.secret_string != null
    ])
    error_message = "Cada secret con generate_password = false requiere secret_string."
  }
}
