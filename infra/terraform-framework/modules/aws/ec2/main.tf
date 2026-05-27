resource "aws_iam_role" "ssm_role" {
  name = substr("ssm-role-${var.project}-${var.environment}", 0, 64)
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = ["ec2.amazonaws.com",
          "ssm.amazonaws.com"]
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ssm_role.name
}

resource "aws_iam_role_policy_attachment" "ssm_patch_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMPatchAssociation"
  role       = aws_iam_role.ssm_role.name
}

# resource "aws_iam_role_policy_attachment" "ssm_maintenance_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMMaintenanceWindowRole"
#   role       = aws_iam_role.ssm_role.name
# }

resource "aws_iam_instance_profile" "ssm_profile" {
  name = substr("ssm-profile-${var.project}-${var.environment}", 0, 64)
  role = aws_iam_role.ssm_role.name
}

resource "aws_instance" "instance" {
  for_each = var.instances

  ami                         = contains(local.gaviton_instance_types, each.value.instance_type) ? lookup(local.ami_ids, "linux_graviton", each.value.ami) : each.value.ami == "windows" && each.value.sql_licence == true ? local.ami_ids.windows_sql : lookup(local.ami_ids, each.value.ami, each.value.ami)
  instance_type               = each.value.instance_type
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  subnet_id                   = lookup(var.subnets, each.value.subnet_name)
  associate_public_ip_address = each.value.public == true ? true : false
  vpc_security_group_ids      = flatten([for sg_name in each.value.security_groups : [for k, v in var.security_groups : v if can(regex(sg_name, k))]])
  user_data                   = each.value.user_data

  key_name                = each.value.key_pair # != null ? lookup(var.keypairs, each.value.key_pair, null) : null
  disable_api_termination = each.value.disable_api_termination

  root_block_device {
    volume_size = each.value.volume_size != null ? coalesce(each.value.volume_size, each.value.ami == "linux" ? 20 : each.value.ami == "windows" ? 80 : null) : each.value.volume_size
    volume_type = coalesce(each.value.volume_type, "gp3")
    tags = merge(
      contains(keys(each.value), "schedule") ? { "Schedule" = each.value.schedule } : {},
      {
        Name = "${each.value.name}"
      },
    var.tags)
  }

  metadata_options {
    http_tokens                 = each.value.imdsv2_required ? "required" : "optional"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }

  dynamic "ebs_block_device" {
    for_each = compact([
      each.value.opt_disk != null ? "/dev/sdb" : null,
      each.value.swap_disk != null ? "/dev/sdc" : null,
      each.value.data_disk != null ? "/dev/sdd" : null,
      each.value.logs_disk != null ? "/dev/sde" : null,
      each.value.backups_disk != null ? "/dev/sdf" : null,
      each.value.app_disk != null ? "/dev/sdg" : null,
      each.value.applog_disk != null ? "/dev/sdh" : null,
    ])
    content {
      device_name = ebs_block_device.value
      volume_size = (
        ebs_block_device.value == "/dev/sdb" ? each.value.opt_disk :
        ebs_block_device.value == "/dev/sdc" ? each.value.swap_disk :
        ebs_block_device.value == "/dev/sdd" ? each.value.data_disk :
        ebs_block_device.value == "/dev/sde" ? each.value.logs_disk :
        ebs_block_device.value == "/dev/sdf" ? each.value.backups_disk :
        ebs_block_device.value == "/dev/sdg" ? each.value.app_disk :
        each.value.applog_disk
      )
      volume_type = "gp3"
      encrypted   = true
      tags = merge(var.tags, {
        Name = "${each.value.name}-${ebs_block_device.value}"
      })
    }
  }

  lifecycle {
    ignore_changes = [
      ami,
      ebs_block_device, # Ignorar cambios en los discos EBS
      root_block_device # Ignorar cambios en el volumen raíz
    ]
  }

  tags = merge(
    contains(keys(each.value), "schedule") ? { "Schedule" = each.value.schedule } : {},
    {
      Name = "${each.value.name}"
    },
  var.tags, each.value.tags)
}
