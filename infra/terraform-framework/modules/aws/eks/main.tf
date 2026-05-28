# ──────────────────────────────────────────────────────────────────────────────
# CAPA 1 — FASE A: IAM base
# Roles cluster/node/karpenter no dependen del cluster — se crean primero.
# ──────────────────────────────────────────────────────────────────────────────

module "iam" {
  for_each = var.eks
  source   = "./modules/iam"

  cluster_name      = each.key
  karpenter_enabled = try(each.value.addons.karpenter, false)
  tags              = merge(var.tags, try(each.value.tags, {}))
}

# ──────────────────────────────────────────────────────────────────────────────
# CAPA 1 — FASE B: Cluster EKS + OIDC provider
# Depende del cluster_role_arn de la Fase A.
# El OIDC provider vive aquí (no en iam/) para evitar ciclo de dependencias:
#   iam.cluster_role_arn → cluster → cluster.oidc_provider_arn → irsa
# ──────────────────────────────────────────────────────────────────────────────

module "cluster" {
  for_each = var.eks
  source   = "./modules/cluster"

  cluster_name     = each.key
  cluster_role_arn = module.iam[each.key].cluster_role_arn

  kubernetes_version            = try(each.value.cluster.kubernetes_version, "1.33")
  authentication_mode           = try(each.value.cluster.authentication_mode, "API_AND_CONFIG_MAP")
  enable_cluster_creator_admin  = try(each.value.cluster.enable_cluster_creator_admin, false)
  enabled_log_types             = try(each.value.cluster.enabled_log_types, ["api", "audit", "authenticator"])
  kms_key_arn                   = try(each.value.cluster.kms_key_arn, null)
  kms_create_key                = try(each.value.cluster.kms_create_key, false)
  deletion_protection           = try(each.value.cluster.deletion_protection, true)
  bootstrap_self_managed_addons = try(each.value.cluster.bootstrap_self_managed_addons, false)
  upgrade_policy                = try(each.value.cluster.upgrade_policy, "STANDARD")

  vpc_id                                  = each.value.network.vpc_id
  subnet_ids                              = each.value.network.subnet_ids
  control_plane_subnet_ids                = try(each.value.network.control_plane_subnet_ids, null)
  endpoint_public_access                  = try(each.value.network.endpoint_public_access, false)
  endpoint_private_access                 = try(each.value.network.endpoint_private_access, true)
  public_access_cidrs                     = try(each.value.network.public_access_cidrs, ["0.0.0.0/0"])
  cluster_security_group_additional_rules = try(each.value.network.cluster_security_group_additional_rules, {})

  addons = {
    coredns    = try(each.value.addons.coredns, true)
    kube_proxy = try(each.value.addons.kube_proxy, true)
    vpc_cni    = try(each.value.addons.vpc_cni, true)
    ebs_csi    = try(each.value.addons.ebs_csi, true)
  }

  cluster_tags = merge(var.tags, try(each.value.cluster.tags, {}), try(each.value.tags, {}))
  tags         = merge(var.tags, try(each.value.tags, {}))
}

# ──────────────────────────────────────────────────────────────────────────────
# CAPA 1 — FASE C: IRSA roles (requieren OIDC del cluster)
# ──────────────────────────────────────────────────────────────────────────────

module "irsa" {
  for_each = var.eks
  source   = "./modules/irsa"

  cluster_name        = each.key
  oidc_issuer_url     = module.cluster[each.key].oidc_issuer_url
  oidc_provider_arn   = module.cluster[each.key].oidc_provider_arn
  karpenter_enabled   = try(each.value.addons.karpenter, false)
  karpenter_queue_arn = module.iam[each.key].karpenter_queue_arn

  addons = {
    aws_load_balancer_controller = try(each.value.addons.aws_load_balancer_controller, true)
    cert_manager                 = try(each.value.addons.cert_manager, true)
    external_secrets             = try(each.value.addons.external_secrets, true)
    external_dns                 = try(each.value.addons.external_dns, false)
    velero                       = try(each.value.addons.velero, false)
    ebs_csi                      = try(each.value.addons.ebs_csi, true)
    karpenter                    = try(each.value.addons.karpenter, false)
    monitoring                   = try(each.value.monitoring.mode, "disabled") != "disabled"
  }

  monitoring_bucket_arn = try(each.value.monitoring.mode, "disabled") != "disabled" ? "arn:aws:s3:::${local.monitoring_bucket[each.key]}" : ""

  tags = merge(var.tags, try(each.value.tags, {}))

  depends_on = [module.cluster]
}

# ──────────────────────────────────────────────────────────────────────────────
# CAPA 1 — FASE D: Node Groups
# ──────────────────────────────────────────────────────────────────────────────

module "node_group" {
  for_each = var.eks
  source   = "./modules/node-group"

  cluster_name         = module.cluster[each.key].cluster_name
  cluster_endpoint     = module.cluster[each.key].cluster_endpoint
  cluster_ca           = module.cluster[each.key].cluster_certificate_authority_data
  cluster_service_cidr = module.cluster[each.key].cluster_service_cidr
  node_role_arn        = module.iam[each.key].node_role_arn
  subnet_ids           = each.value.network.subnet_ids

  cluster_tools_node_group = try(each.value.compute.cluster_tools_node_group, {})
  workload_node_groups     = try(each.value.compute.workload_node_groups, {})

  tags = merge(var.tags, try(each.value.tags, {}))

  depends_on = [module.cluster]
}

# ──────────────────────────────────────────────────────────────────────────────
# CAPA 1 — FASE E: Access Entries / aws-auth
# ──────────────────────────────────────────────────────────────────────────────

module "access" {
  for_each = var.eks
  source   = "./modules/access"

  cluster_name        = module.cluster[each.key].cluster_name
  authentication_mode = try(each.value.cluster.authentication_mode, "API_AND_CONFIG_MAP")
  auth_mode           = try(each.value.auth.mode, "access_entries")

  admins                    = try(each.value.auth.admins, {})
  developers                = try(each.value.auth.developers, {})
  readonly                  = try(each.value.auth.readonly, {})
  additional_access_entries = try(each.value.auth.additional_access_entries, {})

  tags = merge(var.tags, try(each.value.tags, {}))

  depends_on = [module.cluster]
}

# ──────────────────────────────────────────────────────────────────────────────
# CAPA 2 — Bootstrap: genera tfvars y ejecuta terraform en el módulo bootstrap/
# Se ejecuta en el mismo directorio que este módulo (path.module)
# ──────────────────────────────────────────────────────────────────────────────

locals {
  cluster_region = { for k, v in var.eks : k => try(v.account.region, data.aws_region.current.id) }
}

resource "local_file" "bootstrap_tfvars" {
  for_each = var.eks

  filename = "${path.module}/bootstrap/generated/${each.key}.tfvars.json"
  content = jsonencode({
    cluster_name     = each.key
    cluster_region   = local.cluster_region[each.key]
    cluster_version  = module.cluster[each.key].cluster_version
    cluster_endpoint = module.cluster[each.key].cluster_endpoint
    cluster_ca       = module.cluster[each.key].cluster_certificate_authority_data
    vpc_id           = each.value.network.vpc_id

    irsa_roles = {
      aws_load_balancer_controller = module.irsa[each.key].irsa_aws_lb_controller_arn
      external_secrets             = module.irsa[each.key].irsa_external_secrets_arn
      cert_manager                 = module.irsa[each.key].irsa_cert_manager_arn
      external_dns                 = module.irsa[each.key].irsa_external_dns_arn
      velero                       = module.irsa[each.key].irsa_velero_arn
      monitoring                   = module.irsa[each.key].irsa_monitoring_arn
      karpenter                    = module.irsa[each.key].irsa_karpenter_arn
    }

    addons = {
      cert_manager                 = try(each.value.addons.cert_manager, true)
      aws_load_balancer_controller = try(each.value.addons.aws_load_balancer_controller, true)
      external_secrets             = try(each.value.addons.external_secrets, true)
      external_dns                 = try(each.value.addons.external_dns, false)
      metrics_server               = try(each.value.addons.metrics_server, true)
      velero                       = try(each.value.addons.velero, false)
      istio                        = try(each.value.addons.istio, false)
      karpenter                    = try(each.value.addons.karpenter, false)
      keda                         = try(each.value.addons.keda, false)
      cluster_autoscaler           = try(each.value.addons.cluster_autoscaler, false)
      reloader                     = try(each.value.addons.reloader, false)
    }

    helm_versions     = local.helm_versions[each.key]
    monitoring        = try(each.value.monitoring, {})
    monitoring_bucket = local.monitoring_bucket[each.key]

    karpenter_queue_url     = module.iam[each.key].karpenter_queue_url
    karpenter_node_role_arn = module.iam[each.key].karpenter_node_role_arn

    backend_bucket  = var.backend_bucket
    backend_region  = var.backend_region
    assume_role_arn = try(each.value.account.assume_role_arn, "")
  })

  depends_on = [
    module.cluster,
    module.irsa,
    module.node_group,
  ]
}

resource "terraform_data" "bootstrap" {
  for_each = var.eks

  input = local_file.bootstrap_tfvars[each.key].content

  provisioner "local-exec" {
    command = <<-EOT
      bash "${path.module}/../../../scripts/bootstrap.sh" \
        "${each.key}" \
        "${path.module}/bootstrap" \
        "${path.module}/bootstrap/generated/${each.key}.tfvars.json"
    EOT
  }

  depends_on = [
    local_file.bootstrap_tfvars,
    module.node_group,
  ]
}
