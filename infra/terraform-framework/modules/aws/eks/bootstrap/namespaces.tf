locals {
  # Namespaces que se crean si al menos un addon de ese namespace está habilitado
  namespaces_to_create = toset(compact([
    try(var.addons.aws_load_balancer_controller, true) ? "kube-system" : null,
    try(var.addons.cert_manager, true) ? "cert-manager" : null,
    try(var.addons.external_secrets, true) ? "external-secrets" : null,
    try(var.addons.external_dns, false) ? "external-dns" : null,
    try(var.addons.velero, false) ? "velero" : null,
    try(var.addons.istio, false) ? "istio-system" : null,
    try(var.addons.istio, false) ? "istio-ingress" : null,
    try(var.addons.karpenter, false) ? "karpenter" : null,
    try(var.addons.keda, false) ? "keda" : null,
    var.monitoring.mode != "disabled" ? "monitoring" : null,
  ]))
}

resource "kubernetes_namespace_v1" "addons" {
  for_each = { for ns in local.namespaces_to_create : ns => ns if ns != "kube-system" }

  metadata {
    name = each.value
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}
