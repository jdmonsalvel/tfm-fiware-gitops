locals {
  monitoring_enabled_centralized = try(var.monitoring.mode, "disabled") == "centralized"
  central_metrics_enabled        = local.monitoring_enabled_centralized && try(var.monitoring.centralized_config.metrics.enabled, false)
  central_logs_enabled           = local.monitoring_enabled_centralized && try(var.monitoring.centralized_config.logs.enabled, false)
  central_traces_enabled         = local.monitoring_enabled_centralized && try(var.monitoring.centralized_config.traces.enabled, false)
}

# Prometheus en modo agente — solo recolecta y hace remote_write, no almacena
resource "helm_release" "prometheus_agent" {
  count = local.central_metrics_enabled ? 1 : 0

  name             = "prometheus-agent"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  version          = try(var.helm_versions["prometheus_agent"], "0.11.0")
  namespace        = "monitoring"
  create_namespace = false
  wait             = true
  timeout          = 300
  atomic           = true

  values = [yamlencode({
    server = {
      remoteWrite = [{
        url = try(var.monitoring.centralized_config.metrics.remote_write_url, "")
        basicAuth = try(var.monitoring.centralized_config.metrics.secret_ref, "") != "" ? {
          username = { name = var.monitoring.centralized_config.metrics.secret_ref, key = "username" }
          password = { name = var.monitoring.centralized_config.metrics.secret_ref, key = "password" }
        } : null
      }]
      # Modo agente: sin almacenamiento local
      extraFlags = ["enable-feature=agent"]
      retention  = "1h"
    }
  })]

  depends_on = [kubernetes_namespace_v1.addons]
}

# Promtail: log shipper hacia Loki centralizado
resource "helm_release" "promtail_central" {
  count = local.central_logs_enabled ? 1 : 0

  name             = "promtail"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  version          = try(var.helm_versions["promtail"], "6.16.6")
  namespace        = "monitoring"
  create_namespace = false
  wait             = true
  timeout          = 300
  atomic           = true

  values = [yamlencode({
    config = {
      clients = [{
        url = try(var.monitoring.centralized_config.logs.endpoint, "")
        basicAuth = try(var.monitoring.centralized_config.logs.secret_ref, "") != "" ? {
          username = { name = var.monitoring.centralized_config.logs.secret_ref, key = "username" }
          password = { name = var.monitoring.centralized_config.logs.secret_ref, key = "password" }
        } : null
      }]
    }
  })]

  depends_on = [kubernetes_namespace_v1.addons]
}

# OpenTelemetry Collector: para traces hacia backend centralizado
resource "helm_release" "otel_collector" {
  count = local.central_traces_enabled ? 1 : 0

  name             = "opentelemetry-collector"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-collector"
  version          = try(var.helm_versions["opentelemetry_collector"], "0.108.0")
  namespace        = "monitoring"
  create_namespace = false
  wait             = true
  timeout          = 300
  atomic           = true

  values = [yamlencode({
    mode = "daemonset"
    config = {
      exporters = {
        otlp = {
          endpoint = try(var.monitoring.centralized_config.traces.endpoint, "")
        }
      }
      service = {
        pipelines = {
          traces = {
            receivers  = ["otlp"]
            processors = ["batch"]
            exporters  = ["otlp"]
          }
        }
      }
    }
  })]

  depends_on = [kubernetes_namespace_v1.addons]
}
