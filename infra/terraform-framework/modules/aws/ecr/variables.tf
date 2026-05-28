variable "tags" {
  type    = map(string)
  default = {}
}

variable "ecr_repositories" {
  type = map(object({
    name = string

    # Mutabilidad de tags de imagen
    image_tag_mutability = optional(string, "IMMUTABLE") # "IMMUTABLE" | "MUTABLE"

    # Escaneo de vulnerabilidades
    scan_on_push = optional(bool, true)

    # Cifrado
    encryption_type = optional(string, "AES256") # "AES256" | "KMS"
    kms_key_arn     = optional(string, null)     # requerido si encryption_type = "KMS"

    # Lifecycle policy — controla la retención de imágenes
    lifecycle_policy = optional(object({
      # Máximo de imágenes tagged a retener (null = sin límite)
      max_tagged_image_count = optional(number, null)

      # Máximo de imágenes untagged a retener antes de expirar
      max_untagged_image_age_days = optional(number, 7)

      # Reglas adicionales en formato JSON raw (se mezclan con las auto-generadas)
      extra_rules_json = optional(string, null)
    }), {})

    # Política de acceso al repositorio (cross-account pull, CI/CD, EKS)
    repository_policy = optional(string, null) # JSON raw; null = solo la cuenta actual

    # Replicación a otras regiones o cuentas
    # (se configura a nivel de registry, no de repositorio individual)

    # Force delete — permite destruir el repo aunque tenga imágenes
    force_delete = optional(bool, false)

    tags = optional(map(string), {})
  }))
  default = {}
}

# Configuración global del registry (aplica a todos los repos de la cuenta)
variable "registry_scanning" {
  description = "Configuración de escaneo continuo a nivel de registry"
  type = object({
    enabled   = optional(bool, false)
    scan_type = optional(string, "ENHANCED") # "BASIC" | "ENHANCED" (requiere Inspector)
    scan_filters = optional(list(object({
      filter      = string # wildcard, ej: "prod/*"
      filter_type = string # "WILDCARD"
    })), [])
  })
  default = {}
}

variable "registry_replication" {
  description = "Reglas de replicación cross-region o cross-account del registry"
  type = list(object({
    destination_region     = string
    destination_account_id = optional(string, null) # null = misma cuenta
    repository_filters = optional(list(object({
      filter      = string # "PREFIX_MATCH"
      filter_type = string
    })), [])
  }))
  default = []
}
