resource "helm_release" "karpenter" {
  count = try(var.addons.karpenter, false) ? 1 : 0

  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = try(var.helm_versions["karpenter"], "1.3.3")
  namespace        = "karpenter"
  create_namespace = false
  wait             = true
  timeout          = 300
  atomic           = true

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.interruptionQueue"
    value = var.karpenter_queue_url
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = try(var.irsa_roles.karpenter, "")
  }

  depends_on = [
    helm_release.cert_manager,
    kubernetes_namespace_v1.addons,
  ]
}

# NodePool y EC2NodeClass por defecto — gestionados por Karpenter
resource "kubernetes_manifest" "karpenter_node_class" {
  count = try(var.addons.karpenter, false) ? 1 : 0

  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      amiFamily = "AL2023"
      role      = var.karpenter_node_role_arn
      subnetSelectorTerms = [{
        tags = { "kubernetes.io/cluster/${var.cluster_name}" = "shared" }
      }]
      securityGroupSelectorTerms = [{
        tags = { "aws:eks:cluster-name" = var.cluster_name }
      }]
    }
  }

  depends_on = [helm_release.karpenter]
}

resource "kubernetes_manifest" "karpenter_node_pool" {
  count = try(var.addons.karpenter, false) ? 1 : 0

  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "default"
    }
    spec = {
      template = {
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          requirements = [
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand"] },
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
            { key = "karpenter.k8s.aws/instance-category", operator = "In", values = ["m", "c", "r"] },
            { key = "karpenter.k8s.aws/instance-generation", operator = "Gt", values = ["5"] }
          ]
        }
      }
      limits = {
        cpu    = "1000"
        memory = "1000Gi"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "1m"
      }
    }
  }

  depends_on = [kubernetes_manifest.karpenter_node_class]
}
