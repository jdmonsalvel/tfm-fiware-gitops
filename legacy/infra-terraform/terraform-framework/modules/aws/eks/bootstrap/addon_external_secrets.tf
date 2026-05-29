resource "helm_release" "external_secrets" {
  count = try(var.addons.external_secrets, true) ? 1 : 0

  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = try(var.helm_versions["external_secrets"], "0.14.0")
  namespace        = "external-secrets"
  create_namespace = false
  wait             = true
  timeout          = 300
  atomic           = true

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = try(var.irsa_roles.external_secrets, "")
  }

  depends_on = [
    helm_release.cert_manager,
    kubernetes_namespace_v1.addons,
  ]
}
