output "irsa_aws_lb_controller_arn" {
  value = try(var.addons.aws_load_balancer_controller, true) ? aws_iam_role.irsa_aws_lb_controller[0].arn : ""
}

output "irsa_external_secrets_arn" {
  value = try(var.addons.external_secrets, true) ? aws_iam_role.irsa_external_secrets[0].arn : ""
}

output "irsa_cert_manager_arn" {
  value = try(var.addons.cert_manager, true) ? aws_iam_role.irsa_cert_manager[0].arn : ""
}

output "irsa_external_dns_arn" {
  value = try(var.addons.external_dns, false) ? aws_iam_role.irsa_external_dns[0].arn : ""
}

output "irsa_ebs_csi_arn" {
  value = try(var.addons.ebs_csi, true) ? aws_iam_role.irsa_ebs_csi[0].arn : ""
}

output "irsa_velero_arn" {
  value = try(var.addons.velero, false) ? aws_iam_role.irsa_velero[0].arn : ""
}

output "irsa_monitoring_arn" {
  value = try(var.addons.monitoring, false) ? aws_iam_role.irsa_monitoring[0].arn : ""
}

output "irsa_karpenter_arn" {
  value = var.karpenter_enabled ? aws_iam_role.irsa_karpenter[0].arn : ""
}
