output "cluster_name" {
  value = aws_eks_cluster.cluster.name
}

output "cluster_arn" {
  value = aws_eks_cluster.cluster.arn
}

output "cluster_endpoint" {
  value = aws_eks_cluster.cluster.endpoint
}

output "cluster_version" {
  value = aws_eks_cluster.cluster.version
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.cluster.certificate_authority[0].data
}

output "oidc_issuer_url" {
  value = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.cluster.arn
}

output "cluster_security_group_id" {
  value = aws_security_group.cluster.id
}

output "node_security_group_id" {
  # EKS crea automáticamente un SG para nodos — accesible vía el atributo vpc_config
  value = aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
}

output "cluster_service_cidr" {
  value = try(aws_eks_cluster.cluster.kubernetes_network_config[0].service_ipv4_cidr, "172.20.0.0/16")
}
