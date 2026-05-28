output "key_pair_names" {
  description = "Map of keypair name to EC2 key pair name"
  value       = { for k, v in aws_key_pair.keypair : k => v.key_name }
}

output "ssm_parameter_arns" {
  description = "Map of keypair name to SSM parameter ARN where the private key is stored"
  value       = { for k, v in aws_ssm_parameter.parameter : k => v.arn }
}