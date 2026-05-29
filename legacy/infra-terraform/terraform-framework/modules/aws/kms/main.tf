resource "aws_kms_key" "key" {
  for_each            = var.kms_keys
  description         = each.value.description
  enable_key_rotation = try(each.value.enable_key_rotation, false)
  policy              = try(each.value.policy, null)
  tags = merge(
    var.tags,
    try(each.value.tags, {}),
    { Name = each.key }
  )
}

resource "aws_kms_alias" "alias" {
  for_each      = var.kms_keys
  name          = "alias/${each.key}"
  target_key_id = aws_kms_key.key[each.key].key_id
}