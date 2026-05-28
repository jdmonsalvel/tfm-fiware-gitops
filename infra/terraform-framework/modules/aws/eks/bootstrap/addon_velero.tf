resource "helm_release" "velero" {
  count = try(var.addons.velero, false) ? 1 : 0

  name             = "velero"
  repository       = "https://vmware-tanzu.github.io/helm-charts"
  chart            = "velero"
  version          = try(var.helm_versions["velero"], "8.4.0")
  namespace        = "velero"
  create_namespace = false
  wait             = true
  timeout          = 300
  atomic           = true

  set {
    name  = "serviceAccount.server.annotations.eks\\.amazonaws\\.com/role-arn"
    value = try(var.irsa_roles.velero, "")
  }

  set {
    name  = "configuration.backupStorageLocation[0].provider"
    value = "aws"
  }

  set {
    name  = "configuration.backupStorageLocation[0].bucket"
    value = var.monitoring_bucket != "" ? "${var.monitoring_bucket}-velero" : "velero-${var.cluster_name}"
  }

  set {
    name  = "configuration.backupStorageLocation[0].config.region"
    value = var.cluster_region
  }

  set {
    name  = "initContainers[0].name"
    value = "velero-plugin-for-aws"
  }

  set {
    name  = "initContainers[0].image"
    value = "velero/velero-plugin-for-aws:v1.10.1"
  }

  set {
    name  = "initContainers[0].volumeMounts[0].mountPath"
    value = "/target"
  }

  set {
    name  = "initContainers[0].volumeMounts[0].name"
    value = "plugins"
  }

  depends_on = [
    helm_release.cert_manager,
    kubernetes_namespace_v1.addons,
  ]
}
