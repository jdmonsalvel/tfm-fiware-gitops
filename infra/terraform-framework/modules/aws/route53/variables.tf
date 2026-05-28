variable "tags" {
  type    = map(string)
  default = {}
}

variable "route53_zones" {
  type = map(object({
    name              = string
    comment           = optional(string, "")
    vpc_ids           = optional(list(string), []) # privada si non-empty
    delegation_set_id = optional(string, null)     # solo zonas públicas
    force_destroy     = optional(bool, false)
    tags              = optional(map(string), {})
  }))
  default = {}
}

variable "route53_records" {
  type = map(object({
    zone_key = string # clave del mapa route53_zones
    name     = string # relativo o FQDN — Route53 acepta ambos
    type     = string # A | AAAA | CNAME | MX | TXT | NS | SRV | CAA

    ttl     = optional(number, 300)
    records = optional(list(string), []) # IPs, FQDNs, strings TXT…

    alias = optional(object({
      name                   = string
      zone_id                = string
      evaluate_target_health = optional(bool, true)
    }), null)

    health_check_id = optional(string, null)
    set_identifier  = optional(string, null) # obligatorio con routing policies

    weighted_routing = optional(object({
      weight = number
    }), null)

    latency_routing = optional(object({
      region = string
    }), null)

    failover_routing = optional(object({
      type = string # "PRIMARY" | "SECONDARY"
    }), null)
  }))
  default = {}
}
