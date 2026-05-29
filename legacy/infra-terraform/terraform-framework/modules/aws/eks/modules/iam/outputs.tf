output "cluster_role_arn" {
  value = aws_iam_role.cluster.arn
}

output "cluster_role_name" {
  value = aws_iam_role.cluster.name
}

output "node_role_arn" {
  value = aws_iam_role.node.arn
}

output "node_role_name" {
  value = aws_iam_role.node.name
}

output "karpenter_node_role_arn" {
  value = var.karpenter_enabled ? aws_iam_role.karpenter_node[0].arn : ""
}

output "karpenter_queue_url" {
  value = var.karpenter_enabled ? aws_sqs_queue.karpenter[0].url : ""
}

output "karpenter_queue_arn" {
  value = var.karpenter_enabled ? aws_sqs_queue.karpenter[0].arn : ""
}
