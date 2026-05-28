# Outputs planos siguiendo el patrón del framework: { cluster_name → valor }

output "cluster_names" {
  description = "Nombres de los clusters EKS creados"
  value       = { for k, _ in var.eks : k => k }
}

output "cluster_arns" {
  description = "ARNs de los clusters EKS"
  value       = { for k, v in module.cluster : k => v.cluster_arn }
}

output "cluster_endpoints" {
  description = "Endpoints del API server de cada cluster"
  value       = { for k, v in module.cluster : k => v.cluster_endpoint }
}

output "cluster_versions" {
  description = "Versión de Kubernetes de cada cluster"
  value       = { for k, v in module.cluster : k => v.cluster_version }
}

output "cluster_certificate_authority_data" {
  description = "CA data (base64) de cada cluster"
  value       = { for k, v in module.cluster : k => v.cluster_certificate_authority_data }
  sensitive   = true
}

output "oidc_issuer_urls" {
  description = "URLs del OIDC issuer de cada cluster"
  value       = { for k, v in module.cluster : k => v.oidc_issuer_url }
}

output "oidc_provider_arns" {
  description = "ARNs de los OIDC providers"
  value       = { for k, v in module.cluster : k => v.oidc_provider_arn }
}

output "cluster_security_group_ids" {
  description = "SG adicional del control plane de cada cluster"
  value       = { for k, v in module.cluster : k => v.cluster_security_group_id }
}

output "node_security_group_ids" {
  description = "SG de nodos (gestionado por EKS) de cada cluster"
  value       = { for k, v in module.cluster : k => v.node_security_group_id }
}

output "cluster_role_arns" {
  description = "ARNs de los cluster IAM roles"
  value       = { for k, v in module.iam : k => v.cluster_role_arn }
}

output "node_role_arns" {
  description = "ARNs de los node IAM roles"
  value       = { for k, v in module.iam : k => v.node_role_arn }
}

output "karpenter_queue_urls" {
  description = "URLs de las SQS queues de Karpenter"
  value       = { for k, v in module.iam : k => v.karpenter_queue_url }
}

output "karpenter_node_role_arns" {
  description = "ARNs de los IAM roles para nodos gestionados por Karpenter"
  value       = { for k, v in module.iam : k => v.karpenter_node_role_arn }
}

output "irsa_aws_lb_controller_arns" {
  description = "ARNs IRSA del AWS Load Balancer Controller por cluster"
  value       = { for k, v in module.irsa : k => v.irsa_aws_lb_controller_arn }
}

output "irsa_external_secrets_arns" {
  description = "ARNs IRSA del External Secrets Operator por cluster"
  value       = { for k, v in module.irsa : k => v.irsa_external_secrets_arn }
}

output "irsa_cert_manager_arns" {
  description = "ARNs IRSA de cert-manager por cluster"
  value       = { for k, v in module.irsa : k => v.irsa_cert_manager_arn }
}

output "irsa_monitoring_arns" {
  description = "ARNs IRSA de monitoring (Loki/Prometheus) por cluster"
  value       = { for k, v in module.irsa : k => v.irsa_monitoring_arn }
}
