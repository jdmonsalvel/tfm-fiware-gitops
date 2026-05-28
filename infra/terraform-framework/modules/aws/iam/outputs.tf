# ── OIDC Providers ─────────────────────────────────────────────────────────────

output "oidc_provider_arns" {
  description = "Map of OIDC provider key to ARN — usar en trust policies de roles IRSA o GitHub Actions"
  value       = { for k, v in aws_iam_openid_connect_provider.oidc : k => v.arn }
}

# ── Roles ──────────────────────────────────────────────────────────────────────

output "iam_role_arns" {
  description = "Map of role name to role ARN — usar en trust policies, IRSA, ECS task roles"
  value       = { for k, v in aws_iam_role.role : k => v.arn }
}

output "iam_role_names" {
  description = "Map of role name to role name (IAM name)"
  value       = { for k, v in aws_iam_role.role : k => v.name }
}

output "iam_role_unique_ids" {
  description = "Map of role name to stable unique ID (útil en trust policies de otros roles)"
  value       = { for k, v in aws_iam_role.role : k => v.unique_id }
}

output "iam_instance_profile_arns" {
  description = "Map of role name to instance profile ARN — para EC2/ASG con roles custom"
  value       = { for k, v in aws_iam_instance_profile.profile : k => v.arn }
}

output "iam_instance_profile_names" {
  description = "Map of role name to instance profile name — para EC2/ASG con roles custom"
  value       = { for k, v in aws_iam_instance_profile.profile : k => v.name }
}

# ── Políticas ──────────────────────────────────────────────────────────────────

output "iam_policy_arns" {
  description = "Map of policy name to policy ARN — base para adjuntar a roles/usuarios/grupos por nombre"
  value       = { for k, v in aws_iam_policy.policy : k => v.arn }
}

# ── Usuarios ───────────────────────────────────────────────────────────────────

output "iam_user_arns" {
  description = "Map of user name to user ARN"
  value       = { for k, v in aws_iam_user.user : k => v.arn }
}

output "iam_user_names" {
  description = "Map of user name to IAM user name"
  value       = { for k, v in aws_iam_user.user : k => v.name }
}

# ── Grupos ─────────────────────────────────────────────────────────────────────

output "iam_group_arns" {
  description = "Map of group name to group ARN"
  value       = { for k, v in aws_iam_group.group : k => v.arn }
}

output "iam_group_names" {
  description = "Map of group name to IAM group name"
  value       = { for k, v in aws_iam_group.group : k => v.name }
}
