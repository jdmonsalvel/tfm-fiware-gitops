data "aws_vpcs" "vpc_id" {
  count = var.vpc_name != null ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["*${var.vpc_name}*"]
  }
}

data "aws_instances" "asg_instances" {
  instance_tags = {
    Name = "*-asg*"  # O el tag que uses en el ASG
  }
  instance_state_names = ["running"]
  depends_on = [module.autoscaling_group]
}

data "aws_instance" "asg_instance_details" {
  for_each = toset(data.aws_instances.asg_instances.ids)
  
  instance_id = each.value
}

# data "aws_subnets" "subnet_ids" {
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpcs.vpc_id.ids[0]]
#   }
# }

# data "aws_subnet" "subnet_ids" {
#   for_each = toset(data.aws_subnets.subnet_ids.ids)

#   id = each.value
# }

# data "aws_security_groups" "security_group_ids" {

#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpcs.vpc_id.ids[0]]
#   }
# }

# data "aws_security_group" "security_group_ids" {
#   for_each = toset(data.aws_security_groups.security_group_ids.ids)

#   id = each.value
# }
