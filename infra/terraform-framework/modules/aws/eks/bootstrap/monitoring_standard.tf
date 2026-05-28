locals {
  monitoring_enabled_standard = try(var.monitoring.mode, "disabled") == "standard"
  retention_days              = try(var.monitoring.storage.retention_days, 30)
}

# S3 bucket para almacenamiento de Loki y métricas de largo plazo
resource "aws_s3_bucket" "monitoring" {
  count  = local.monitoring_enabled_standard && try(var.monitoring.storage.create_bucket, true) ? 1 : 0
  bucket = var.monitoring_bucket

  tags = { Name = var.monitoring_bucket, ManagedBy = "terraform" }
}

resource "aws_s3_bucket_lifecycle_configuration" "monitoring" {
  count  = local.monitoring_enabled_standard && try(var.monitoring.storage.create_bucket, true) ? 1 : 0
  bucket = aws_s3_bucket.monitoring[0].id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    expiration { days = local.retention_days }
    filter { prefix = "" }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "monitoring" {
  count  = local.monitoring_enabled_standard && try(var.monitoring.storage.create_bucket, true) ? 1 : 0
  bucket = aws_s3_bucket.monitoring[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# kube-prometheus-stack: Prometheus + Alertmanager + Grafana + exporters
resource "helm_release" "kube_prometheus_stack" {
  count = local.monitoring_enabled_standard ? 1 : 0

  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = try(var.helm_versions["kube_prometheus_stack"], "70.4.2")
  namespace        = "monitoring"
  create_namespace = false
  wait             = true
  timeout          = 600
  atomic           = true

  values = [yamlencode({
    prometheus = {
      prometheusSpec = {
        retention = "${local.retention_days}d"
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = "gp3"
              resources        = { requests = { storage = "50Gi" } }
            }
          }
        }
      }
    }
    grafana = {
      adminPassword = "changeme-use-external-secrets"
      persistence = {
        enabled          = true
        storageClassName = "gp3"
        size             = "10Gi"
      }
    }
    alertmanager = {
      alertmanagerSpec = {
        storage = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = "gp3"
              resources        = { requests = { storage = "10Gi" } }
            }
          }
        }
      }
    }
  })]

  depends_on = [
    kubernetes_namespace_v1.addons,
    aws_s3_bucket.monitoring,
  ]
}

# Loki: backend S3 para logs
resource "helm_release" "loki" {
  count = local.monitoring_enabled_standard ? 1 : 0

  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  version          = try(var.helm_versions["loki"], "6.28.0")
  namespace        = "monitoring"
  create_namespace = false
  wait             = true
  timeout          = 600
  atomic           = true

  values = [yamlencode({
    loki = {
      commonConfig = { replication_factor = 1 }
      storage = {
        type = "s3"
        s3 = {
          region = var.cluster_region
          bucketNames = {
            chunks = var.monitoring_bucket
            ruler  = var.monitoring_bucket
            admin  = var.monitoring_bucket
          }
        }
      }
    }
    singleBinary = {
      replicas = 1
      persistence = {
        enabled      = true
        storageClass = "gp3"
        size         = "20Gi"
      }
      extraEnv = [{
        name  = "AWS_ROLE_ARN"
        value = try(var.irsa_roles.monitoring, "")
      }]
    }
    serviceAccount = {
      annotations = {
        "eks.amazonaws.com/role-arn" = try(var.irsa_roles.monitoring, "")
      }
    }
    deploymentMode = "SingleBinary"
    backend        = { replicas = 0 }
    read           = { replicas = 0 }
    write          = { replicas = 0 }
  })]

  depends_on = [
    helm_release.kube_prometheus_stack,
    aws_s3_bucket.monitoring,
  ]
}

# Promtail: agente que envía logs al Loki local
resource "helm_release" "promtail" {
  count = local.monitoring_enabled_standard ? 1 : 0

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
        url = "http://loki:3100/loki/api/v1/push"
      }]
    }
  })]

  depends_on = [helm_release.loki]
}
