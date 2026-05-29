# ──────────────────────────────────────────────────────────────────────────────
# LAUNCH TEMPLATES
# Separados por node group para AMIs custom vs. AMI gestionada por EKS
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_launch_template" "node_group" {
  for_each = local.all_node_groups

  name_prefix = "${var.cluster_name}-${each.key}-"

  dynamic "block_device_mappings" {
    for_each = [1]
    content {
      device_name = "/dev/xvda"
      ebs {
        volume_size           = each.value.config.disk_size
        volume_type           = each.value.config.disk_type
        encrypted             = true
        delete_on_termination = true
      }
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 obligatorio
    http_put_response_hop_limit = 2          # 2 necesario para pods en el nodo
  }

  # AMI custom: si ami_id = null, EKS selecciona la imagen según versión K8s + ami_type
  image_id  = each.value.config.ami_id
  user_data = each.value.config.ami_id != null ? base64encode(local.userdata_al2023) : null

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, each.value.config.tags, { Name = "${var.cluster_name}-${each.key}" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags, each.value.config.tags, { Name = "${var.cluster_name}-${each.key}-vol" })
  }

  tags = merge(var.tags, each.value.config.tags, { Name = "${var.cluster_name}-${each.key}-lt" })

  lifecycle {
    create_before_destroy = true
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# EKS NODE GROUPS
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_eks_node_group" "node_group" {
  for_each = local.all_node_groups

  cluster_name    = var.cluster_name
  node_group_name = "${var.cluster_name}-${each.key}"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  capacity_type  = each.value.config.capacity_type
  instance_types = each.value.config.instance_types

  # Cuando ami_id = null: EKS gestiona la AMI, NO especificar ami_type en launch template
  # Cuando ami_id != null: CUSTOM, el launch template tiene la imagen
  ami_type = each.value.config.ami_id == null ? each.value.config.ami_type : "CUSTOM"

  launch_template {
    id      = aws_launch_template.node_group[each.key].id
    version = aws_launch_template.node_group[each.key].latest_version
  }

  scaling_config {
    min_size     = each.value.config.min_size
    max_size     = each.value.config.max_size
    desired_size = each.value.config.desired_size
  }

  update_config {
    max_unavailable_percentage = 33
  }

  labels = each.value.config.labels

  dynamic "taint" {
    for_each = each.value.config.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(var.tags, each.value.config.tags, { Name = "${var.cluster_name}-${each.key}" })

  lifecycle {
    # Evitar reemplazar node groups por cambios de desired_size (el CA/Karpenter lo gestiona)
    ignore_changes = [scaling_config[0].desired_size]
  }
}
