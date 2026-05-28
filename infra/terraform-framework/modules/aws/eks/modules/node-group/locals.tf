locals {
  # User data MIME multipart con nodeadm para AL2023 con AMI custom
  # Ref: https://docs.aws.amazon.com/eks/latest/userguide/launch-templates.html
  userdata_al2023 = <<-USERDATA
    Content-Type: multipart/mixed; boundary="//"
    MIME-Version: 1.0

    --//
    Content-Type: application/node.eks.aws

    ---
    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      cluster:
        name: ${var.cluster_name}
        apiServerEndpoint: ${var.cluster_endpoint}
        certificateAuthority: ${var.cluster_ca}
        cidr: ${var.cluster_service_cidr}
    --//--
  USERDATA

  # Todos los node groups en un mapa unificado (cluster-tools + workload)
  all_node_groups = merge(
    {
      "cluster-tools" = {
        config         = var.cluster_tools_node_group
        is_tools_group = true
      }
    },
    {
      for k, v in var.workload_node_groups : k => {
        config         = v
        is_tools_group = false
      }
    }
  )
}
