output "hub_stack_ids" {
  description = "Map de nombre_clave → Stack ID del hub"
  value       = { for k, v in aws_cloudformation_stack.hub : k => v.id }
}

output "hub_scheduler_role_arns" {
  description = "Map de nombre_clave → ARN del rol Lambda del hub (necesario para configurar spokes cross-account)"
  value = {
    for k, v in aws_cloudformation_stack.hub : k =>
    lookup(v.outputs, "SchedulerRoleArn", "")
  }
}

output "hub_config_table_names" {
  description = "Map de nombre_clave → nombre de la tabla DynamoDB de configuración"
  value       = local.hub_config_tables
}

output "spoke_stack_ids" {
  description = "Map de nombre_clave → Stack ID del spoke"
  value       = { for k, v in aws_cloudformation_stack.spoke : k => v.id }
}

output "ec2_tagged_instance_ids" {
  description = "Map de nombre_clave → lista de instance IDs a los que se aplicó el tag de schedule"
  value = {
    for assoc_key in keys(local.ec2_associations) :
    assoc_key => try(data.aws_instances.scheduled[assoc_key].ids, [])
  }
}
