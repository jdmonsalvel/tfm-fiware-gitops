resource "helm_release" "reloader" {
  count = try(var.addons.reloader, false) ? 1 : 0

  name             = "reloader"
  repository       = "https://stakater.github.io/stakater-charts"
  chart            = "reloader"
  version          = try(var.helm_versions["reloader"], "1.4.0")
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 300
  atomic           = true

  depends_on = [kubernetes_namespace_v1.addons]
}
