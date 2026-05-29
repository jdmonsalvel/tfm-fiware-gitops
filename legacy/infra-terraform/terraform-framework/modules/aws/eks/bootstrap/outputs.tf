output "cert_manager_installed" {
  value = try(var.addons.cert_manager, true) && length(helm_release.cert_manager) > 0
}

output "monitoring_mode" {
  value = try(var.monitoring.mode, "disabled")
}
