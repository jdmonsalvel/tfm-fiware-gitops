locals {
  # Versiones por defecto de Helm charts (mayo 2026)
  default_helm_chart_versions = {
    aws_load_balancer_controller = "1.10.0"
    cert_manager                 = "v1.17.2"
    external_secrets             = "0.14.0"
    external_dns                 = "1.15.2"
    metrics_server               = "3.12.2"
    velero                       = "8.4.0"
    istio_base                   = "1.24.3"
    istiod                       = "1.24.3"
    karpenter                    = "1.3.3"
    keda                         = "2.16.1"
    cluster_autoscaler           = "9.46.6"
    reloader                     = "1.4.0"
    kube_prometheus_stack        = "70.4.2"
    loki                         = "6.28.0"
    grafana                      = "8.10.4"
    prometheus_agent             = "0.11.0"
    promtail                     = "6.16.6"
    opentelemetry_collector      = "0.108.0"
  }

  # Versión real = override del usuario o default
  helm_versions = {
    for cluster_name, cluster in var.eks :
    cluster_name => merge(
      local.default_helm_chart_versions,
      try(cluster.addons.helm_chart_versions, {})
    )
  }

  # Nombre del bucket de monitoring
  monitoring_bucket = {
    for cluster_name, cluster in var.eks :
    cluster_name => try(
      cluster.monitoring.storage.s3_bucket_name,
      "eks-monitoring-${cluster_name}-${data.aws_caller_identity.current.account_id}"
    )
  }

  # Nombre final del cluster (la clave del mapa)
  cluster_names = { for k, _ in var.eks : k => k }
}
