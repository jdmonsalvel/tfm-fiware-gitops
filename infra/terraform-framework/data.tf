data "aws_vpcs" "vpc_id" {
  count = var.vpc_name != null ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["*${var.vpc_name}*"]
  }
}

# data "aws_instances" / "aws_instance" para ASG suprimidos:
# for_each sobre IDs post-apply no es soportado en plan.
# Los outputs asg_instance_ids y asg_private_ips retornan {} cuando no hay ASG.

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
