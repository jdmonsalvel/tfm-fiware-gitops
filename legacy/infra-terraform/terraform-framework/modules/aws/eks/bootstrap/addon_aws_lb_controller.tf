resource "helm_release" "aws_load_balancer_controller" {
  count = try(var.addons.aws_load_balancer_controller, true) ? 1 : 0

  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = try(var.helm_versions["aws_load_balancer_controller"], "1.10.0")
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 300
  atomic           = true

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = try(var.irsa_roles.aws_load_balancer_controller, "")
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  # cert-manager debe estar listo antes (webhooks)
  depends_on = [
    helm_release.cert_manager,
    kubernetes_namespace_v1.addons,
  ]
}
