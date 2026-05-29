resource "helm_release" "external_dns" {
  count = try(var.addons.external_dns, false) ? 1 : 0

  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = try(var.helm_versions["external_dns"], "1.15.2")
  namespace        = "external-dns"
  create_namespace = false
  wait             = true
  timeout          = 300
  atomic           = true

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = try(var.irsa_roles.external_dns, "")
  }

  set {
    name  = "provider"
    value = "aws"
  }

  depends_on = [
    helm_release.cert_manager,
    kubernetes_namespace_v1.addons,
  ]
}
