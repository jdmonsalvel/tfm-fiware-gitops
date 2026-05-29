resource "helm_release" "cert_manager" {
  count = try(var.addons.cert_manager, true) ? 1 : 0

  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = try(var.helm_versions["cert_manager"], "v1.17.2")
  namespace        = "cert-manager"
  create_namespace = false # ya creado en namespaces.tf
  wait             = true
  timeout          = 300
  atomic           = true

  set {
    name  = "crds.enabled"
    value = "true"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = try(var.irsa_roles.cert_manager, "")
  }

  depends_on = [kubernetes_namespace_v1.addons]
}
