resource "helm_release" "metrics_server" {
  count = try(var.addons.metrics_server, true) ? 1 : 0

  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = try(var.helm_versions["metrics_server"], "3.12.2")
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 300
  atomic           = true

  depends_on = [kubernetes_namespace_v1.addons]
}
