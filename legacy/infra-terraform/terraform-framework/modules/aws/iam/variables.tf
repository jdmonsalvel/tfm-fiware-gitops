variable "tags" {
  type    = map(string)
  default = {}
}

variable "iam_roles" {
  description = "Roles IAM genéricos de aplicación o cross-service. Los roles específicos de servicio (SSM, Lambda exec) se crean en su propio módulo."
  type = map(object({
    name        = string
    description = optional(string, "")
    path        = optional(string, "/")

    # ── Trust policy — opción A: helpers declarativos ─────────────────────────
    # Cada bloque trust_statements es un Statement independiente con su propio
    # Principal + Action + Condition. Cubre todos los patrones de confianza sin
    # necesidad de escribir JSON en el tfvars.
    trust_statements = optional(list(object({
      effect  = optional(string, "Allow")
      actions = optional(list(string), ["sts:AssumeRole"])

      # Principal — especificar uno de los tres tipos
      service_principals   = optional(list(string), []) # ["ec2.amazonaws.com"]
      aws_principals       = optional(list(string), []) # ["arn:aws:iam::123:root"]
      federated_principals = optional(list(string), []) # OIDC/SAML provider ARNs

      # Condiciones opcionales — mapa de { test => { variable => [valores] } }
      # Ejemplo IRSA:  { "StringEquals" => { "oidc.eks.region.amazonaws.com/id/XXX:sub" => ["system:serviceaccount:ns:sa"] } }
      # Ejemplo ExternalId: { "StringEquals" => { "sts:ExternalId" => ["mi-external-id"] } }
      # Ejemplo MFA:   { "Bool" => { "aws:MultiFactorAuthPresent" => ["true"] } }
      conditions = optional(map(map(list(string))), {})
    })), [])

    # ── Trust policy — opción B: JSON raw (sobreescribe completamente los helpers)
    assume_role_policy = optional(string)

    # Políticas adjuntas
    managed_policy_arns = optional(list(string), []) # ARNs de AWS managed o externas
    policy_names        = optional(list(string), []) # nombres de iam_policies creadas en este módulo

    # Políticas inline (name => json_string)
    inline_policies = optional(map(string), {})

    # Configuración del role
    max_session_duration = optional(number, 3600)
    permissions_boundary = optional(string)

    # Crear aws_iam_instance_profile (necesario para EC2/ASG custom roles)
    create_instance_profile = optional(bool, false)

    tags = optional(map(string), {})
  }))
  default = {}
}

variable "iam_policies" {
  description = "Políticas IAM reutilizables. Se pueden adjuntar a roles, usuarios y grupos por nombre."
  type = map(object({
    name        = string
    description = optional(string, "")
    path        = optional(string, "/")
    policy      = string # JSON de la política
    tags        = optional(map(string), {})
  }))
  default = {}
}

variable "iam_users" {
  description = "Usuarios IAM para acceso programático (CI/CD, integraciones). Preferir OIDC sobre usuarios con access keys en producción."
  type = map(object({
    name          = string
    path          = optional(string, "/")
    force_destroy = optional(bool, false)

    managed_policy_arns = optional(list(string), [])
    policy_names        = optional(list(string), [])
    inline_policies     = optional(map(string), {})
    group_memberships   = optional(list(string), []) # nombres de grupos en iam_groups

    tags = optional(map(string), {})
  }))
  default = {}
}

variable "iam_groups" {
  description = "Grupos IAM para gestionar colectivos de usuarios con los mismos permisos."
  type = map(object({
    name = string
    path = optional(string, "/")

    managed_policy_arns = optional(list(string), [])
    policy_names        = optional(list(string), [])
    inline_policies     = optional(map(string), {})
  }))
  default = {}
}

variable "iam_oidc_providers" {
  description = "Proveedores OIDC de IAM a nivel de cuenta. Necesarios para IRSA de EKS o OIDC de GitHub Actions."
  type = map(object({
    url             = string        # e.g. "https://token.actions.githubusercontent.com"
    client_id_list  = list(string)  # e.g. ["sts.amazonaws.com"]
    thumbprint_list = list(string)  # SHA1 del cert raíz del proveedor
    tags            = optional(map(string), {})
  }))
  default = {}
}
