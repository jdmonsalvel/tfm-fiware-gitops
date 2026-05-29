resource "helm_release" "cluster_autoscaler" {
  # Mutuamente excluyente con karpenter — la validación está en variables.tf del módulo EKS raíz
  count = try(var.addons.cluster_autoscaler, false) && !try(var.addons.karpenter, false) ? 1 : 0

  name             = "cluster-autoscaler"
  repository       = "https://kubernetes.github.io/autoscaler"
  chart            = "cluster-autoscaler"
  version          = try(var.helm_versions["cluster_autoscaler"], "9.46.6")
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 300
  atomic           = true

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.cluster_region
  }

  depends_on = [kubernetes_namespace_v1.addons]
}
