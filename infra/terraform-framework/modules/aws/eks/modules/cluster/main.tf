# ──────────────────────────────────────────────────────────────────────────────
# KMS KEY (opcional — solo si kms_create_key = true)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_kms_key" "cluster" {
  count               = var.kms_create_key ? 1 : 0
  description         = "KMS key para cifrado de secrets etcd del cluster ${var.cluster_name}"
  enable_key_rotation = true
  tags                = merge(var.tags, var.cluster_tags, { Name = "${var.cluster_name}-kms" })
}

resource "aws_kms_alias" "cluster" {
  count         = var.kms_create_key ? 1 : 0
  name          = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.cluster[0].key_id
}

# ──────────────────────────────────────────────────────────────────────────────
# SECURITY GROUP DEL CLUSTER
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group del control plane de EKS ${var.cluster_name}"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, var.cluster_tags, { Name = "${var.cluster_name}-cluster-sg" })
}

resource "aws_security_group_rule" "cluster_additional" {
  for_each = var.cluster_security_group_additional_rules

  security_group_id = aws_security_group.cluster.id
  description       = each.value.description
  protocol          = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  type              = each.value.type

  cidr_blocks              = length(each.value.cidr_blocks) > 0 ? each.value.cidr_blocks : null
  ipv6_cidr_blocks         = length(each.value.ipv6_cidr_blocks) > 0 ? each.value.ipv6_cidr_blocks : null
  source_security_group_id = each.value.source_cluster_security_group ? aws_security_group.cluster.id : each.value.source_security_group_id
}

# ──────────────────────────────────────────────────────────────────────────────
# TAGS EN SUBNETS — requeridos por EKS para auto-discovery de ALB
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_ec2_tag" "subnet_cluster" {
  # Índice numérico como clave para que for_each funcione cuando los IDs de
  # subnet son desconocidos en plan-time (caso single-apply desde estado vacío).
  for_each    = { for idx, id in var.subnet_ids : tostring(idx) => id }
  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "shared"
}

# ──────────────────────────────────────────────────────────────────────────────
# EKS CLUSTER
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "cluster" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = var.enable_cluster_creator_admin
  }

  vpc_config {
    subnet_ids              = local.control_plane_subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_public_access  = var.endpoint_public_access
    endpoint_private_access = var.endpoint_private_access
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : null
  }

  enabled_cluster_log_types = var.enabled_log_types

  dynamic "encryption_config" {
    for_each = local.kms_key_arn != null ? [1] : []
    content {
      resources = ["secrets"]
      provider {
        key_arn = local.kms_key_arn
      }
    }
  }

  bootstrap_self_managed_addons = var.bootstrap_self_managed_addons

  upgrade_policy {
    support_type = var.upgrade_policy
  }

  tags = merge(var.tags, var.cluster_tags, { Name = var.cluster_name })

  lifecycle {
    prevent_destroy = false
    # access_config.bootstrap_cluster_creator_admin_permissions es inmutable en EKS
    # (solo se puede establecer en la creación, no modificar tras crear el cluster).
    ignore_changes = [
      tags,
      access_config,
    ]
  }

  depends_on = [aws_security_group.cluster]
}

# ──────────────────────────────────────────────────────────────────────────────
# OIDC PROVIDER — requerido para IRSA (IAM Roles for Service Accounts)
# Vive aquí (no en el módulo iam) para evitar dependencia circular:
#   iam.cluster_role_arn → cluster → cluster.oidc_issuer_url → irsa
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_iam_openid_connect_provider" "cluster" {
  url             = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]

  tags = merge(var.tags, var.cluster_tags, { Name = "${var.cluster_name}-oidc-provider" })

  depends_on = [aws_eks_cluster.cluster]
}

# ──────────────────────────────────────────────────────────────────────────────
# EKS MANAGED ADDONS (coredns, kube-proxy, vpc-cni, ebs-csi)
# Estos addons son AWS managed — no Helm
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_eks_addon" "coredns" {
  count = try(var.addons.coredns, true) ? 1 : 0

  cluster_name                = aws_eks_cluster.cluster.name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(var.tags, var.cluster_tags)
}

resource "aws_eks_addon" "kube_proxy" {
  count = try(var.addons.kube_proxy, true) ? 1 : 0

  cluster_name                = aws_eks_cluster.cluster.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(var.tags, var.cluster_tags)
}

resource "aws_eks_addon" "vpc_cni" {
  count = try(var.addons.vpc_cni, true) ? 1 : 0

  cluster_name                = aws_eks_cluster.cluster.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(var.tags, var.cluster_tags)
}

resource "aws_eks_addon" "ebs_csi" {
  count = try(var.addons.ebs_csi, true) ? 1 : 0

  cluster_name                = aws_eks_cluster.cluster.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(var.tags, var.cluster_tags)
}
