output "access_entry_arns" {
  value = { for k, v in aws_eks_access_entry.this : k => v.access_entry_arn }
}
