output "node_group_arns" {
  value = { for k, v in aws_eks_node_group.node_group : k => v.arn }
}

output "node_group_statuses" {
  value = { for k, v in aws_eks_node_group.node_group : k => v.status }
}

output "node_group_ids" {
  value = { for k, v in aws_eks_node_group.node_group : k => v.id }
}
