locals {
  use_access_entries = contains(["access_entries", "hybrid"], var.auth_mode)

  # Aplanar admins, developers, readonly en un mapa único para for_each
  admin_entries = var.auth_mode != "aws_auth" ? {
    for arn in try(var.admins.principal_arns, []) :
    replace(arn, "/[:/.]/", "-") => {
      principal_arn       = arn
      kubernetes_groups   = try(var.admins.kubernetes_groups, [])
      policy_associations = try(var.admins.policy_associations, [])
      type                = "STANDARD"
    }
  } : {}

  developer_entries = var.auth_mode != "aws_auth" ? {
    for arn in try(var.developers.principal_arns, []) :
    replace(arn, "/[:/.]/", "-") => {
      principal_arn       = arn
      kubernetes_groups   = try(var.developers.kubernetes_groups, [])
      policy_associations = try(var.developers.policy_associations, [])
      type                = "STANDARD"
    }
  } : {}

  readonly_entries = var.auth_mode != "aws_auth" ? {
    for arn in try(var.readonly.principal_arns, []) :
    replace(arn, "/[:/.]/", "-") => {
      principal_arn       = arn
      kubernetes_groups   = try(var.readonly.kubernetes_groups, [])
      policy_associations = try(var.readonly.policy_associations, [])
      type                = "STANDARD"
    }
  } : {}

  additional_entries = var.auth_mode != "aws_auth" ? {
    for k, v in var.additional_access_entries :
    k => {
      principal_arn       = v.principal_arn
      kubernetes_groups   = v.kubernetes_groups
      policy_associations = v.policy_associations
      type                = v.type
    }
  } : {}

  all_entries = merge(local.admin_entries, local.developer_entries, local.readonly_entries, local.additional_entries)

  # Aplanar policy_associations para for_each de aws_eks_access_policy_association
  all_policy_associations = flatten([
    for entry_key, entry in local.all_entries : [
      for policy_arn in entry.policy_associations : {
        key           = "${entry_key}--${replace(policy_arn, "/[:/.]/", "-")}"
        principal_arn = entry.principal_arn
        policy_arn    = policy_arn
      }
    ]
  ])
}

# ──────────────────────────────────────────────────────────────────────────────
# ACCESS ENTRIES (API mode — recomendado)
# Compatible con authentication_mode = "API" o "API_AND_CONFIG_MAP"
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_eks_access_entry" "this" {
  for_each = local.use_access_entries ? local.all_entries : {}

  cluster_name      = var.cluster_name
  principal_arn     = each.value.principal_arn
  type              = each.value.type
  kubernetes_groups = length(each.value.kubernetes_groups) > 0 ? each.value.kubernetes_groups : null

  tags = merge(var.tags, { Name = "${var.cluster_name}-access-${each.key}" })

  lifecycle {
    precondition {
      condition     = !local.use_access_entries || var.authentication_mode != "CONFIG_MAP"
      error_message = "auth.mode=access_entries requiere authentication_mode=API o API_AND_CONFIG_MAP, no CONFIG_MAP."
    }
  }
}

resource "aws_eks_access_policy_association" "this" {
  for_each = local.use_access_entries ? {
    for assoc in local.all_policy_associations : assoc.key => assoc
  } : {}

  cluster_name  = var.cluster_name
  principal_arn = each.value.principal_arn
  policy_arn    = each.value.policy_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.this]
}
