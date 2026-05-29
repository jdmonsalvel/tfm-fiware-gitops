output "ec2_instance_ids" {
  description = "Map of instance name to instance ID"
  value       = { for k, s in aws_instance.instance : k => s.id }
}

output "ec2_instance_arns" {
  description = "Map of instance name to instance ARN"
  value       = { for k, s in aws_instance.instance : k => s.arn }
}

output "ec2_public_ips" {
  description = "Map of instance name to public IP"
  value       = { for k, s in aws_instance.instance : k => s.public_ip }
}

output "ec2_private_ips" {
  description = "Map of instance name to private IP"
  value       = { for k, s in aws_instance.instance : k => s.private_ip }
}

output "ec2_private_dns_names" {
  description = "Map of instance name to private DNS name"
  value       = { for k, s in aws_instance.instance : k => s.private_dns }
}