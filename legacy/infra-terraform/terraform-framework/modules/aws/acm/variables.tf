variable "tags" {
  type    = map(string)
  default = {}
}

variable "acm_certificates" {
  type = map(object({
    domain_name               = string
    subject_alternative_names = optional(list(string), [])
    validation_method         = optional(string, "DNS") # "DNS" | "EMAIL"

    # Clave del mapa zone_ids donde crear los CNAME de validación.
    # Si null el certificado se crea pero la validación DNS es manual.
    zone_key = optional(string, null)

    # RSA_2048 (compatible universal) | EC_prime256v1 | EC_secp384r1
    key_algorithm = optional(string, "RSA_2048")

    tags = optional(map(string), {})
  }))
  default = {}
}

# Output directo del módulo route53: module.route53[0].zone_ids
variable "zone_ids" {
  description = "Map de zone_key → zone_id (output del módulo route53)"
  type        = map(string)
  default     = {}
}

# Si false (default) los CNAME de validación se crean en Route53 pero el apply no bloquea
# esperando que ACM los resuelva. Activar solo cuando Route53 ya sea el DNS autoritativo.
variable "wait_for_validation" {
  type    = bool
  default = false
}
