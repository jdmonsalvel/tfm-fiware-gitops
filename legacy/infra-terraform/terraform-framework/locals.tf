locals {
  tags = {
    Deploy      = "terraform"
    Accountable = var.accountable
    Environment = var.environment
    Project     = var.project
  }
}

locals {
  vpc_id = var.vpc_name != null && length(data.aws_vpcs.vpc_id) > 0 ? try(data.aws_vpcs.vpc_id[0].ids[0], null) : null
}

locals {
  existing_vpc_id = var.vpc_name != null ? {
    "${var.vpc_name}" = data.aws_vpcs.vpc_id[0].ids[0]
  } : {}
  vpc_ids    = merge(module.vpc.vpc_ids, local.existing_vpc_id)
  subnet_ids = module.subnet.subnet_ids
}

# locals {
#   security_groups = merge({
#     for sg_key, sg_value in data.aws_security_group.security_group_ids :
#     sg_value.tags.Name => sg_key
#     if length(sg_value.tags) > 0 && contains(keys(sg_value.tags), "Name")
#   }, module.security_groups.security_group_ids)
# }

# locals {
#   subnets = {
#     for subnet in data.aws_subnet.subnet_ids :
#     subnet.tags["Name"] => subnet.id
#   }
# }

# locals {
#   should_create_ec2 = length(var.ec2_instances) > 0
# }