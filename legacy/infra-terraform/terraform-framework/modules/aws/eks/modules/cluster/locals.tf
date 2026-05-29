locals {
  # Subnets del control plane: usar las especificadas o las de nodos
  control_plane_subnet_ids = var.control_plane_subnet_ids != null ? var.control_plane_subnet_ids : var.subnet_ids

  # KMS key para cifrado de secrets de etcd
  kms_key_arn = var.kms_create_key ? aws_kms_key.cluster[0].arn : var.kms_key_arn
}
