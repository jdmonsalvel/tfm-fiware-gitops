resource "aws_key_pair" "keypair" {
  for_each   = var.keypairs
  key_name   = each.value.name
  public_key = tls_private_key.keypair[each.key].public_key_openssh
  tags = merge(
    var.tags,
    each.value.tags,
    { Name = each.value.name }
  )
}

resource "tls_private_key" "keypair" {
  for_each  = var.keypairs
  algorithm = each.value.algorithm
  rsa_bits  = each.value.algorithm == "RSA" ? each.value.rsa_bits : null
}

resource "aws_ssm_parameter" "parameter" {
  for_each = var.keypairs
  name     = each.value.ssm_path_prefix != null ? "${each.value.ssm_path_prefix}/${each.value.name}" : "/${var.environment}/EC2/${each.value.name}"
  type     = "SecureString"
  key_id   = each.value.kms_key_id
  value    = tls_private_key.keypair[each.key].private_key_pem
  tags = merge(
    { Name = each.value.name },
    var.tags,
    each.value.tags
  )
}