locals {

  # ────────────────────────────────────────────────────────────
  # ROLES — policy attachments aplanados para for_each
  # ────────────────────────────────────────────────────────────

  role_managed_attachments = {
    for pair in flatten([
      for role_key, role in var.iam_roles : [
        for arn in coalesce(role.managed_policy_arns, []) : {
          key        = "${role_key}--${element(split("/", arn), length(split("/", arn)) - 1)}"
          role_name  = aws_iam_role.role[role_key].name
          policy_arn = arn
        }
      ]
    ]) : pair.key => pair
  }

  # Políticas creadas en este mismo módulo, referenciadas por nombre
  role_custom_policy_attachments = {
    for pair in flatten([
      for role_key, role in var.iam_roles : [
        for policy_name in coalesce(role.policy_names, []) : {
          key        = "${role_key}--${policy_name}"
          role_name  = aws_iam_role.role[role_key].name
          policy_arn = aws_iam_policy.policy[policy_name].arn
        }
      ]
    ]) : pair.key => pair
  }

  role_inline_policies = {
    for pair in flatten([
      for role_key, role in var.iam_roles : [
        for policy_name, policy_json in coalesce(role.inline_policies, {}) : {
          key         = "${role_key}--${policy_name}"
          role_name   = aws_iam_role.role[role_key].name
          policy_name = policy_name
          policy      = policy_json
        }
      ]
    ]) : pair.key => pair
  }

  # Roles que necesitan instance profile (para EC2/ASG personalizados)
  instance_profile_roles = {
    for k, v in var.iam_roles : k => v if v.create_instance_profile
  }

  # ────────────────────────────────────────────────────────────
  # USUARIOS — policy attachments y membresías
  # ────────────────────────────────────────────────────────────

  user_managed_attachments = {
    for pair in flatten([
      for user_key, user in var.iam_users : [
        for arn in coalesce(user.managed_policy_arns, []) : {
          key        = "${user_key}--${element(split("/", arn), length(split("/", arn)) - 1)}"
          user_name  = aws_iam_user.user[user_key].name
          policy_arn = arn
        }
      ]
    ]) : pair.key => pair
  }

  user_custom_policy_attachments = {
    for pair in flatten([
      for user_key, user in var.iam_users : [
        for policy_name in coalesce(user.policy_names, []) : {
          key        = "${user_key}--${policy_name}"
          user_name  = aws_iam_user.user[user_key].name
          policy_arn = aws_iam_policy.policy[policy_name].arn
        }
      ]
    ]) : pair.key => pair
  }

  user_inline_policies = {
    for pair in flatten([
      for user_key, user in var.iam_users : [
        for policy_name, policy_json in coalesce(user.inline_policies, {}) : {
          key         = "${user_key}--${policy_name}"
          user_name   = aws_iam_user.user[user_key].name
          policy_name = policy_name
          policy      = policy_json
        }
      ]
    ]) : pair.key => pair
  }

  # ────────────────────────────────────────────────────────────
  # GRUPOS — policy attachments
  # ────────────────────────────────────────────────────────────

  group_managed_attachments = {
    for pair in flatten([
      for group_key, group in var.iam_groups : [
        for arn in coalesce(group.managed_policy_arns, []) : {
          key        = "${group_key}--${element(split("/", arn), length(split("/", arn)) - 1)}"
          group_name = aws_iam_group.group[group_key].name
          policy_arn = arn
        }
      ]
    ]) : pair.key => pair
  }

  group_custom_policy_attachments = {
    for pair in flatten([
      for group_key, group in var.iam_groups : [
        for policy_name in coalesce(group.policy_names, []) : {
          key        = "${group_key}--${policy_name}"
          group_name = aws_iam_group.group[group_key].name
          policy_arn = aws_iam_policy.policy[policy_name].arn
        }
      ]
    ]) : pair.key => pair
  }

  group_inline_policies = {
    for pair in flatten([
      for group_key, group in var.iam_groups : [
        for policy_name, policy_json in coalesce(group.inline_policies, {}) : {
          key         = "${group_key}--${policy_name}"
          group_name  = aws_iam_group.group[group_key].name
          policy_name = policy_name
          policy      = policy_json
        }
      ]
    ]) : pair.key => pair
  }
}
