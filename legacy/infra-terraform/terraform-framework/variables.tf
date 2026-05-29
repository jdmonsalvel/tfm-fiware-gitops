variable "account_id" {
  type    = string
  default = ""
}

variable "region" {
  type        = string
  default     = null
  description = "AWS region in which resources will get deployed. Defaults to Ireland."
}
variable "project" {
  type = string
}
variable "environment" {
  type = string
}
variable "accountable" {
  type = string
}
variable "vpc_name" {
  type    = string
  default = null
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "vpcs" {
  description = "Map of VPC configurations"
  type = map(object({
    name                 = string
    cidr_block           = string
    instance_tenancy     = optional(string, "default")
    enable_dns_support   = optional(bool, true)
    enable_dns_hostnames = optional(bool, true)
    tags                 = optional(map(string))
    enable_flow_logs     = optional(bool, false)
  }))
  default = {}
}
variable "vpc_flow_logs" {
  description = "Map of VPC configurations"
  type = map(object({
    vpc_name         = string
    enable_flow_logs = optional(bool, false)
    tags             = optional(map(string))
  }))
  default = {}
}
variable "dhcp_option_sets" {
  type = map(object({
    name                = string
    domain_name         = string
    vpc_name            = string
    domain-name-servers = optional(list(string))
    tags                = optional(map(string))
  }))
  default = {}
}

variable "subnets" {
  type = map(object({
    cidr_block        = string
    availability_zone = string
    vpc_name          = string
    name              = string
    network_acl_name  = optional(string, null)
    ip_public_auto    = optional(bool, false)
    db_subnet         = optional(bool, false)
    tags              = optional(map(string))
  }))
  default = {}
}

variable "rds_instances" {
  description = "Map of RDS instance configurations"
  type = map(object({
    name                        = string
    engine                      = string
    engine_version              = string
    instance_class              = string
    db_name                     = optional(string)
    username                    = string
    manage_master_user_password = optional(bool, true)
    multi_az                    = optional(bool, false)
    allocated_storage           = optional(number, 20)
    max_allocated_storage       = optional(number, 100)
    storage_type                = optional(string, "gp3")
    storage_encrypted           = optional(bool, true)
    backup_retention_period     = optional(number, 7)
    deletion_protection         = optional(bool, false)
    skip_final_snapshot         = optional(bool, true)
    security_group_names        = list(string)
    tags                        = optional(map(string), {})
  }))
  default = {}
}
variable "enable_rds_subnet_group" {
  type    = bool
  default = false
}
variable "subnet_route_tables" {
  type = map(object({
    name          = string
    vpc_name      = string
    subnets_names = list(string)
    tags          = optional(map(string))
    routes = map(object({
      destiny = string
      target  = string
    }))
  }))
  default = {}
}

variable "network_acls" {
  description = "Map of network ACLs with their rules"
  type = map(object({
    name     = string
    vpc_name = string
    tags     = optional(map(string))
    rules = map(object({
      rule_number = number
      type        = string
      protocol    = string
      rule_action = string
      cidr_block  = string
      from_port   = number
      to_port     = number
    }))
  }))
  default = {}
}

variable "internet_gateways" {
  type = map(object({
    name     = string
    vpc_name = string
    tags     = optional(map(string))
  }))
  default = {}
}

variable "nat_gateways" {
  type = map(object({
    name                 = string
    subnet_name          = string
    connectivity_type    = string
    eip_allocation_id    = optional(string)
    primary_private_ipv4 = optional(string)
    tags                 = optional(map(string))
  }))
  default = {}
}

variable "security_groups" {
  description = "Map of security group definitions"
  type = map(object({
    name        = string
    description = optional(string)
    vpc_name    = optional(string)
    ingress = optional(map(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
      description = optional(string)
    })), {})
    egress = optional(map(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
      description = optional(string)
    })), {})
    tags = optional(map(string))
  }))
  default = {}
}

variable "transit_gateway_id" {
  type    = string
  default = null
}
variable "transit_gateway_attachments" {
  type = map(object({
    name                 = string
    vpc_name             = string
    transit_gateway_name = optional(string)
    subnet_names         = list(string)
    tags                 = optional(map(string))
  }))
  default = {}
}
variable "transit_gateways" {
  description = "Map of transit gateways to create"
  type = map(object({
    name                            = string
    description                     = optional(string, null)
    amazon_side_asn                 = optional(number, 64512)
    auto_accept_shared_attachments  = optional(string, "enable")
    default_route_table_association = optional(string, "disable")
    default_route_table_propagation = optional(string, "disable")
    vpn_ecmp_support                = optional(string, "enable")
    dns_support                     = optional(string, "enable")
    multicast_support               = optional(string, "disable")
    tags                            = optional(map(string))
  }))
  default = {}
}
variable "transit_gateway_route_tables" {
  description = "Map of transit gateway route tables to create"
  type = map(object({
    name                 = string
    transit_gateway_name = string
    tags                 = optional(map(string))
    routes = optional(map(object({
      destiny = string
      target  = string
    })))
  }))
  default = {}
}
variable "kms_keys" {
  description = "Mapa de llaves KMS a crear"
  type = map(object({
    description         = optional(string, "")
    enable_key_rotation = optional(bool, true)
    tags                = optional(map(string), {})
    policy              = optional(string, null)
  }))
  default = {}
}

variable "regional_nat_gateways" {
  description = "Mapa de Regional NAT Gateways (un único NAT por región, sin afinidad de AZ)"
  type = map(object({
    name              = string
    connectivity_type = optional(string, "public")
    eip_allocation_id = optional(string)
    tags              = optional(map(string), {})
  }))
  default = {}
}
variable "ec2_instances" {
  description = "Mapa de configuraciones para las instancias"
  type = map(object({
    name                = string
    ami                 = string
    instance_type       = string
    security_groups     = optional(list(string))
    sql_licence         = optional(bool, false)
    virtual_ips         = optional(list(string), [])
    subnet_type         = optional(string)
    subnet_name         = optional(string)
    az                  = optional(string)
    subnet_id           = optional(string, null)
    key_pair            = optional(string)
    security_group_name = optional(string)
    user_data           = optional(string)
    service_ip          = optional(string)
    management_ip       = optional(string)
    volume_size         = optional(number)
    volume_type         = optional(string, "gp3")
    iops                = optional(number)
    schedule            = optional(string)
    enable_metadata     = optional(bool, false)
    tags                = optional(map(string))
    opt_disk            = optional(number)
    swap_disk           = optional(number)
    tempdb_disk         = optional(number)
    templog_disk        = optional(number)
    paging_disk         = optional(number)
    data_disk           = optional(number)
    logs_disk           = optional(number)
    backups_disk        = optional(number)
    app_disk            = optional(number)
    applog_disk         = optional(number)
    public              = optional(bool, false)

  }))
  default = {}
}
variable "keypairs" {
  description = "Map of keypair definitions"
  type = map(object({
    name = string
    tags = optional(map(string))
  }))
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
    tags                      = optional(map(string), {})
  }))

  default = {}
}

variable "iam_roles" {
  description = "Roles IAM genéricos de aplicación o cross-service"
  type = map(object({
    name        = string
    description = optional(string, "")
    path        = optional(string, "/")

    # Opción A: statements declarativos con condiciones (IRSA, ExternalId, MFA...)
    trust_statements = optional(list(object({
      effect               = optional(string, "Allow")
      actions              = optional(list(string), ["sts:AssumeRole"])
      service_principals   = optional(list(string), [])
      aws_principals       = optional(list(string), [])
      federated_principals = optional(list(string), [])
      conditions           = optional(map(map(list(string))), {})
    })), [])

    # Opción B: campos simples sin condiciones
    service_principals   = optional(list(string), [])
    aws_principals       = optional(list(string), [])
    federated_principals = optional(list(string), [])

    # Opción C: JSON raw (sobreescribe todo)
    assume_role_policy = optional(string)

    managed_policy_arns     = optional(list(string), [])
    policy_names            = optional(list(string), [])
    inline_policies         = optional(map(string), {})
    max_session_duration    = optional(number, 3600)
    permissions_boundary    = optional(string)
    create_instance_profile = optional(bool, false)
    tags                    = optional(map(string), {})
  }))
  default = {}
}

variable "iam_policies" {
  description = "Políticas IAM reutilizables"
  type = map(object({
    name        = string
    description = optional(string, "")
    path        = optional(string, "/")
    policy      = string
    tags        = optional(map(string), {})
  }))
  default = {}
}

variable "iam_users" {
  description = "Usuarios IAM para acceso programático"
  type = map(object({
    name                = string
    path                = optional(string, "/")
    force_destroy       = optional(bool, false)
    managed_policy_arns = optional(list(string), [])
    policy_names        = optional(list(string), [])
    inline_policies     = optional(map(string), {})
    group_memberships   = optional(list(string), [])
    tags                = optional(map(string), {})
  }))
  default = {}
}

variable "iam_groups" {
  description = "Grupos IAM para gestión colectiva de permisos"
  type = map(object({
    name                = string
    path                = optional(string, "/")
    managed_policy_arns = optional(list(string), [])
    policy_names        = optional(list(string), [])
    inline_policies     = optional(map(string), {})
  }))
  default = {}
}

variable "iam_oidc_providers" {
  description = "Proveedores OIDC de IAM (GitHub Actions, EKS externo, etc.)"
  type = map(object({
    url             = string
    client_id_list  = list(string)
    thumbprint_list = list(string)
    tags            = optional(map(string), {})
  }))
  default = {}
}

# ──────────────────────────────────────────────────────────────────────────────
# EKS
# ──────────────────────────────────────────────────────────────────────────────

variable "eks_backend_bucket" {
  description = "Bucket S3 para el state del bootstrap de addons EKS (Capa 2)"
  type        = string
  default     = ""
}

variable "eks_backend_region" {
  description = "Región del bucket S3 de backend para el state EKS"
  type        = string
  default     = "eu-west-1"
}

variable "eks" {
  description = "Mapa de clusters EKS — ver modules/aws/eks/variables.tf para el schema completo"
  type        = any
  default     = {}
}

# ──────────────────────────────────────────────────────────────────────────────
# S3
# ──────────────────────────────────────────────────────────────────────────────

variable "s3_buckets" {
  description = "Mapa de buckets S3 — ver modules/aws/s3/variables.tf para el schema completo"
  type        = any
  default     = {}
}

# ──────────────────────────────────────────────────────────────────────────────
# ECR
# ──────────────────────────────────────────────────────────────────────────────

variable "ecr_repositories" {
  description = "Mapa de repositorios ECR — ver modules/aws/ecr/variables.tf para el schema completo"
  type        = any
  default     = {}
}

variable "registry_scanning" {
  description = "Configuración de escaneo continuo ECR a nivel de registry"
  type        = any
  default     = {}
}

variable "registry_replication" {
  description = "Reglas de replicación cross-region / cross-account del registry ECR"
  type        = any
  default     = []
}

# ──────────────────────────────────────────────────────────────────────────────
# ROUTE53
# ──────────────────────────────────────────────────────────────────────────────

variable "route53_zones" {
  description = "Mapa de zonas Route53 — ver modules/aws/route53/variables.tf para el schema completo"
  type        = any
  default     = {}
}

variable "route53_records" {
  description = "Mapa de records DNS — ver modules/aws/route53/variables.tf para el schema completo"
  type        = any
  default     = {}
}

# ──────────────────────────────────────────────────────────────────────────────
# ACM
# ──────────────────────────────────────────────────────────────────────────────

variable "acm_certificates" {
  description = "Mapa de certificados ACM — ver modules/aws/acm/variables.tf para el schema completo"
  type        = any
  default     = {}
}

# ──────────────────────────────────────────────────────────────────────────────
# INSTANCE SCHEDULER
# ──────────────────────────────────────────────────────────────────────────────

variable "instance_schedulers" {
  description = "Mapa de schedulers — ver modules/aws/instance-scheduler/variables.tf para el schema completo"
  type        = any
  default     = {}
}

# ──────────────────────────────────────────────────────────────────────────────
# SECRETS MANAGER
# ──────────────────────────────────────────────────────────────────────────────

variable "secrets_manager_secrets" {
  description = "Mapa de secretos AWS Secrets Manager — ver modules/aws/secrets-manager/variables.tf"
  type        = any
  default     = {}
}

# ──────────────────────────────────────────────────────────────────────────────
# SECURITY GROUP CROSS-RULES
# Reglas de ingress que referencian SGs de origen por nombre (evita dependencia
# circular en el mapa security_groups). Se crean DESPUÉS del módulo de SG.
# ──────────────────────────────────────────────────────────────────────────────

variable "security_group_rules" {
  description = "Reglas de ingress cross-SG: referencian SGs por nombre (key del mapa security_groups)"
  type = map(object({
    sg_name        = string           # SG destino (key en security_groups)
    source_sg_name = optional(string) # SG origen  (key en security_groups); mutuamente exclusivo con cidr_ipv4
    cidr_ipv4      = optional(string) # CIDR origen alternativo
    from_port      = optional(number, -1)
    to_port        = optional(number, -1)
    ip_protocol    = optional(string, "-1")
    description    = optional(string, "")
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.security_group_rules :
      (v.source_sg_name != null) != (v.cidr_ipv4 != null)
    ])
    error_message = "Cada regla debe tener exactamente uno de: source_sg_name o cidr_ipv4."
  }
}
