# ──────────────────────────────────────────────────────────────────────────────
# OIDC PROVIDERS (cuenta-nivel — GitHub Actions, EKS, etc.)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_iam_openid_connect_provider" "oidc" {
  for_each        = var.iam_oidc_providers
  url             = each.value.url
  client_id_list  = each.value.client_id_list
  thumbprint_list = each.value.thumbprint_list
  tags            = merge(var.tags, each.value.tags)
}

# ──────────────────────────────────────────────────────────────────────────────
# ROLES
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "role" {
  for_each = var.iam_roles

  name                 = each.value.name
  description          = each.value.description
  path                 = each.value.path
  max_session_duration = each.value.max_session_duration
  permissions_boundary = each.value.permissions_boundary

  # Prioridad: assume_role_policy (JSON raw) > trust_statements > campos legacy
  assume_role_policy = each.value.assume_role_policy != null ? each.value.assume_role_policy : jsonencode({
    Version = "2012-10-17"
    Statement = length(coalesce(each.value.trust_statements, [])) > 0 ? [
      for stmt in each.value.trust_statements : merge(
        {
          Effect = stmt.effect
          Action = stmt.actions
          Principal = merge(
            length(stmt.service_principals) > 0 ? { Service = stmt.service_principals } : {},
            length(stmt.aws_principals) > 0 ? { AWS = stmt.aws_principals } : {},
            length(stmt.federated_principals) > 0 ? { Federated = stmt.federated_principals } : {}
          )
        },
        length(stmt.conditions) > 0 ? {
          Condition = {
            for test, vars in stmt.conditions : test => {
              for variable, values in vars : variable => values
            }
          }
        } : {}
      )
      ] : concat(
      length(each.value.service_principals) > 0 ? [{
        Effect    = "Allow"
        Principal = { Service = each.value.service_principals }
        Action    = "sts:AssumeRole"
      }] : [],
      length(each.value.aws_principals) > 0 ? [{
        Effect    = "Allow"
        Principal = { AWS = each.value.aws_principals }
        Action    = "sts:AssumeRole"
      }] : [],
      length(each.value.federated_principals) > 0 ? [{
        Effect    = "Allow"
        Principal = { Federated = each.value.federated_principals }
        Action    = "sts:AssumeRoleWithWebIdentity"
      }] : []
    )
  })

  tags = merge(var.tags, each.value.tags, { Name = each.value.name })
}

resource "aws_iam_role_policy_attachment" "role_managed" {
  for_each   = local.role_managed_attachments
  role       = each.value.role_name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_role_policy_attachment" "role_custom" {
  for_each   = local.role_custom_policy_attachments
  role       = each.value.role_name
  policy_arn = each.value.policy_arn
  depends_on = [aws_iam_policy.policy]
}

resource "aws_iam_role_policy" "role_inline" {
  for_each = local.role_inline_policies
  name     = each.value.policy_name
  role     = each.value.role_name
  policy   = each.value.policy
}

resource "aws_iam_instance_profile" "profile" {
  for_each = local.instance_profile_roles
  name     = each.value.name
  role     = aws_iam_role.role[each.key].name
  tags     = merge(var.tags, each.value.tags, { Name = each.value.name })
}

# ──────────────────────────────────────────────────────────────────────────────
# POLÍTICAS STANDALONE
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_iam_policy" "policy" {
  for_each    = var.iam_policies
  name        = each.value.name
  description = each.value.description
  path        = each.value.path
  policy      = each.value.policy
  tags        = merge(var.tags, each.value.tags, { Name = each.value.name })
}

# ──────────────────────────────────────────────────────────────────────────────
# USUARIOS
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_iam_user" "user" {
  for_each      = var.iam_users
  name          = each.value.name
  path          = each.value.path
  force_destroy = each.value.force_destroy
  tags          = merge(var.tags, each.value.tags, { Name = each.value.name })
}

resource "aws_iam_user_policy_attachment" "user_managed" {
  for_each   = local.user_managed_attachments
  user       = each.value.user_name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_user_policy_attachment" "user_custom" {
  for_each   = local.user_custom_policy_attachments
  user       = each.value.user_name
  policy_arn = each.value.policy_arn
  depends_on = [aws_iam_policy.policy]
}

resource "aws_iam_user_policy" "user_inline" {
  for_each = local.user_inline_policies
  name     = each.value.policy_name
  user     = each.value.user_name
  policy   = each.value.policy
}

# Un recurso por usuario gestiona todas sus membresías de grupo
resource "aws_iam_user_group_membership" "membership" {
  for_each   = { for k, v in var.iam_users : k => v if length(coalesce(v.group_memberships, [])) > 0 }
  user       = aws_iam_user.user[each.key].name
  groups     = each.value.group_memberships
  depends_on = [aws_iam_group.group]
}

# ──────────────────────────────────────────────────────────────────────────────
# GRUPOS
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_iam_group" "group" {
  for_each = var.iam_groups
  name     = each.value.name
  path     = each.value.path
}

resource "aws_iam_group_policy_attachment" "group_managed" {
  for_each   = local.group_managed_attachments
  group      = each.value.group_name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_group_policy_attachment" "group_custom" {
  for_each   = local.group_custom_policy_attachments
  group      = each.value.group_name
  policy_arn = each.value.policy_arn
  depends_on = [aws_iam_policy.policy]
}

resource "aws_iam_group_policy" "group_inline" {
  for_each = local.group_inline_policies
  name     = each.value.policy_name
  group    = each.value.group_name
  policy   = each.value.policy
}
