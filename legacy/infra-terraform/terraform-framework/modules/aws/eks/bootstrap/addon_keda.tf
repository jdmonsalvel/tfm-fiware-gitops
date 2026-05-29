resource "helm_release" "keda" {
  count = try(var.addons.keda, false) ? 1 : 0

  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = try(var.helm_versions["keda"], "2.16.1")
  namespace        = "keda"
  create_namespace = false
  wait             = true
  timeout          = 300
  atomic           = true

  depends_on = [
    helm_release.cert_manager,
    kubernetes_namespace_v1.addons,
  ]
}
