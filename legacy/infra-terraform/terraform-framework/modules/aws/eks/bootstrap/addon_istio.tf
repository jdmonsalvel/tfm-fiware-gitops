# Instala Istio en 3 pasos: base → istiod → ingress gateway
# El orden importa: base instala los CRDs, istiod depende de ellos

resource "helm_release" "istio_base" {
  count = try(var.addons.istio, false) ? 1 : 0

  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  version          = try(var.helm_versions["istio_base"], "1.24.3")
  namespace        = "istio-system"
  create_namespace = false
  wait             = true
  timeout          = 300
  atomic           = true

  depends_on = [
    helm_release.cert_manager,
    kubernetes_namespace_v1.addons,
  ]
}

resource "helm_release" "istiod" {
  count = try(var.addons.istio, false) ? 1 : 0

  name             = "istiod"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "istiod"
  version          = try(var.helm_versions["istiod"], "1.24.3")
  namespace        = "istio-system"
  create_namespace = false
  wait             = true
  timeout          = 300
  atomic           = true

  depends_on = [helm_release.istio_base]
}

resource "helm_release" "istio_ingress" {
  count = try(var.addons.istio, false) ? 1 : 0

  name             = "istio-ingress"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "gateway"
  version          = try(var.helm_versions["istiod"], "1.24.3")
  namespace        = "istio-ingress"
  create_namespace = false
  wait             = true
  timeout          = 300
  atomic           = true

  depends_on = [
    helm_release.istiod,
    helm_release.aws_load_balancer_controller,
  ]
}
