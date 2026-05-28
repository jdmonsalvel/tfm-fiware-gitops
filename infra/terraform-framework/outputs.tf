
output "vpc_ids" {
  value = length(module.vpc.vpc_ids) > 0 ? local.vpc_ids : null
}

output "vpc_arns" {
  value = length(module.vpc.vpc_arns) > 0 ? module.vpc.vpc_arns : null
}

output "vpc_cidr_blocks" {
  value = length(module.vpc.vpc_cidr_blocks) > 0 ? module.vpc.vpc_cidr_blocks : null
}

output "subnet_ids" {
  value = length(module.subnet.subnet_ids) > 0 ? local.subnet_ids : null
}

output "subnet_arns" {
  value = length(module.subnet.subnet_arns) > 0 ? module.subnet.subnet_arns : null
}

output "module_network_acl_ids" {
  value = length(module.network_acl.network_acl_ids) > 0 ? module.network_acl.network_acl_ids : null
}

output "dhcp_option_sets_output" {
  value = length(module.dhcp_option_set.dhcp_option_set_ids) > 0 ? module.dhcp_option_set.dhcp_option_set_ids : null
}

output "internet_gateway_ids" {
  value = length(module.internet_gateways.internet_gateway_ids) > 0 ? module.internet_gateways.internet_gateway_ids : null
}

output "nat_gateway_ids" {
  value = length(module.nat_gw.nat_gateway_ids) > 0 ? module.nat_gw.nat_gateway_ids : null
}

output "security_group_ids" {
  value = length(module.security_group.security_group_ids) > 0 ? module.security_group.security_group_ids : null
}

output "security_group_arns" {
  value = length(module.security_group.security_group_arns) > 0 ? module.security_group.security_group_arns : null
}

output "transit_gateway_attachment_ids" {
  value = length(module.transit_gateway_attachment.transit_gateway_attachment_ids) > 0 ? module.transit_gateway_attachment.transit_gateway_attachment_ids : null
}

output "route_table_ids" {
  value = length(module.subnet_route_table.route_table_ids) > 0 ? module.subnet_route_table.route_table_ids : null
}

output "transit_gateway_ids" {
  value = length(module.transit_gateway.transit_gateway_ids) > 0 ? module.transit_gateway.transit_gateway_ids : null
}

output "transit_gateway_route_table_ids" {
  value = length(module.transit_gateway_route_table) > 0 ? module.transit_gateway_route_table[0].transit_gateway_route_table_ids : null
}

output "ec2_instance_ids" {
  description = "Map of instance name to instance ID"
  value       = length(module.ec2) > 0 ? module.ec2[0].ec2_instance_ids : null
}

output "ec2_public_ips" {
  description = "Map of instance name to public IP"
  value       = length(module.ec2) > 0 ? module.ec2[0].ec2_public_ips : null
}

output "ec2_private_ips" {
  description = "Map of instance name to private IP"
  value       = length(module.ec2) > 0 ? module.ec2[0].ec2_private_ips : null
}

output "ec2_private_dns_names" {
  description = "Map of instance name to private DNS name"
  value       = length(module.ec2) > 0 ? module.ec2[0].ec2_private_dns_names : null
}

output "alb_dns_names" {
  description = "Map of ASG name to ALB DNS name"
  value       = length(module.autoscaling_group) > 0 ? module.autoscaling_group[0].alb_dns_names : null
}

output "db_subnet_group_name" {
  description = "Name of the shared DB subnet group (used by RDS and DocumentDB)"
  value       = length(module.db_subnet_group) > 0 ? module.db_subnet_group[0].db_subnet_group_name : null
}

output "rds_instance_ids" {
  description = "Map of RDS instance name to instance ID"
  value       = length(module.rds) > 0 ? module.rds[0].rds_instance_ids : null
}

output "rds_instance_endpoints" {
  description = "Map of RDS instance name to connection endpoint"
  value       = length(module.rds) > 0 ? module.rds[0].rds_instance_endpoints : null
}

output "autoscaling_group_arns" {
  description = "Map of ASG name to Auto Scaling Group ARN"
  value       = length(module.autoscaling_group) > 0 ? module.autoscaling_group[0].autoscaling_group_arns : null
}


output "asg_instance_ids" {
  value = {}
}

output "asg_private_ips" {
  value = {}
}

output "kms_key_ids" {
  description = "Map of KMS key name to key ID"
  value       = length(module.kms) > 0 ? module.kms[0].kms_key_ids : null
}

output "kms_key_arns" {
  description = "Map of KMS key name to key ARN"
  value       = length(module.kms) > 0 ? module.kms[0].kms_key_arns : null
}

output "kms_alias_arns" {
  description = "Map of KMS key name to alias ARN"
  value       = length(module.kms) > 0 ? module.kms[0].kms_alias_arns : null
}

output "regional_nat_gateway_ids" {
  description = "Map of Regional NAT Gateway name to NAT Gateway ID"
  value       = length(module.regional_nat_gw) > 0 ? module.regional_nat_gw[0].regional_nat_gateway_ids : null
}

output "regional_nat_gateway_public_ips" {
  description = "Map of Regional NAT Gateway name to public IP"
  value       = length(module.regional_nat_gw) > 0 ? module.regional_nat_gw[0].regional_nat_gateway_public_ips : null
}

output "iam_oidc_provider_arns" {
  description = "Map de OIDC provider key → ARN (usar en trust policies)"
  value       = length(module.iam) > 0 ? module.iam[0].oidc_provider_arns : {}
}

output "iam_role_arns" {
  description = "Map of IAM role name to ARN"
  value       = length(module.iam) > 0 ? module.iam[0].iam_role_arns : null
}

output "iam_role_names" {
  description = "Map of IAM role name to IAM name"
  value       = length(module.iam) > 0 ? module.iam[0].iam_role_names : null
}

output "iam_instance_profile_arns" {
  description = "Map of role name to instance profile ARN (solo roles con create_instance_profile = true)"
  value       = length(module.iam) > 0 ? module.iam[0].iam_instance_profile_arns : null
}

output "iam_instance_profile_names" {
  description = "Map of role name to instance profile name"
  value       = length(module.iam) > 0 ? module.iam[0].iam_instance_profile_names : null
}

output "iam_policy_arns" {
  description = "Map of IAM policy name to ARN"
  value       = length(module.iam) > 0 ? module.iam[0].iam_policy_arns : null
}

output "iam_user_arns" {
  description = "Map of IAM user name to ARN"
  value       = length(module.iam) > 0 ? module.iam[0].iam_user_arns : null
}

output "iam_group_arns" {
  description = "Map of IAM group name to ARN"
  value       = length(module.iam) > 0 ? module.iam[0].iam_group_arns : null
}
output "eks_cluster_endpoints" {
  description = "Endpoints del API server de cada cluster EKS"
  value       = length(module.eks) > 0 ? module.eks[0].cluster_endpoints : {}
}

output "eks_oidc_provider_arns" {
  description = "ARNs de los OIDC providers EKS"
  value       = length(module.eks) > 0 ? module.eks[0].oidc_provider_arns : {}
}

output "eks_node_role_arns" {
  description = "ARNs de los IAM roles de nodos EKS"
  value       = length(module.eks) > 0 ? module.eks[0].node_role_arns : {}
}

output "s3_bucket_arns" {
  description = "Map de nombre_clave → ARN del bucket S3"
  value       = length(module.s3) > 0 ? module.s3[0].bucket_arns : {}
}

output "s3_bucket_ids" {
  description = "Map de nombre_clave → nombre del bucket S3"
  value       = length(module.s3) > 0 ? module.s3[0].bucket_ids : {}
}

output "ecr_repository_urls" {
  description = "Map de nombre_clave → URL del repositorio ECR"
  value       = length(module.ecr) > 0 ? module.ecr[0].repository_urls : {}
}

output "ecr_repository_arns" {
  description = "Map de nombre_clave → ARN del repositorio ECR"
  value       = length(module.ecr) > 0 ? module.ecr[0].repository_arns : {}
}

output "route53_zone_ids" {
  description = "Map de nombre_clave → ID de zona Route53"
  value       = length(module.route53) > 0 ? module.route53[0].zone_ids : {}
}

output "route53_name_servers" {
  description = "Map de nombre_clave → name servers de zonas públicas"
  value       = length(module.route53) > 0 ? module.route53[0].name_servers : {}
}

output "acm_certificate_arns" {
  description = "Map de nombre_clave → ARN del certificado ACM"
  value       = length(module.acm) > 0 ? module.acm[0].certificate_arns : {}
}

output "acm_certificate_statuses" {
  description = "Map de nombre_clave → estado del certificado ACM"
  value       = length(module.acm) > 0 ? module.acm[0].certificate_statuses : {}
}

output "instance_scheduler_hub_role_arns" {
  description = "Map de nombre_clave → ARN del rol Lambda del hub (usar en spokes)"
  value       = length(module.instance_scheduler) > 0 ? module.instance_scheduler[0].hub_scheduler_role_arns : {}
}

output "instance_scheduler_hub_config_tables" {
  description = "Map de nombre_clave → tabla DynamoDB de configuración del hub"
  value       = length(module.instance_scheduler) > 0 ? module.instance_scheduler[0].hub_config_table_names : {}
}

output "secret_arns" {
  description = "Map de nombre_clave → ARN del secreto en Secrets Manager"
  value       = length(module.secrets_manager) > 0 ? module.secrets_manager[0].secret_arns : {}
}

output "secret_ids" {
  description = "Map de nombre_clave → path del secreto en Secrets Manager"
  value       = length(module.secrets_manager) > 0 ? module.secrets_manager[0].secret_ids : {}
}
