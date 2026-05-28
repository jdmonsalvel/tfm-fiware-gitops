resource "random_password" "generated" {
  for_each = { for k, v in var.secrets_manager_secrets : k => v if v.generate_password }

  length           = 32
  special          = false # alfanumérico puro — compatible con MySQL, MongoDB, URLs
  override_special = ""
}

resource "aws_secretsmanager_secret" "secret" {
  for_each = var.secrets_manager_secrets

  name                    = each.value.name
  description             = each.value.description
  kms_key_id              = each.value.kms_key_id
  recovery_window_in_days = each.value.recovery_window_in_days

  tags = merge(var.tags, each.value.tags, { Name = each.value.name })
}

resource "aws_secretsmanager_secret_version" "secret" {
  for_each = var.secrets_manager_secrets

  secret_id     = aws_secretsmanager_secret.secret[each.key].id
  secret_string = each.value.generate_password ? random_password.generated[each.key].result : each.value.secret_string

  # No sobreescribir si el valor fue actualizado manualmente en AWS Console o CLI
  lifecycle {
    ignore_changes = [secret_string]
  }
}
