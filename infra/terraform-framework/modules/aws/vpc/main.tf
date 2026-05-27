resource "aws_vpc" "vpc" {
  for_each = var.vpcs

  cidr_block           = each.value.cidr_block
  instance_tenancy     = each.value.instance_tenancy
  enable_dns_support   = each.value.enable_dns_support
  enable_dns_hostnames = each.value.enable_dns_hostnames
  tags = merge(
    var.tags,
    {
      Name = "${each.value.name}"
    }
  )
}

resource "aws_flow_log" "local" {
  for_each        = { for k, v in var.vpcs : k => v if try(v.enable_flow_logs, false) }
  iam_role_arn    = aws_iam_role.local_flow_log_role[each.key].arn
  log_destination = aws_cloudwatch_log_group.local_flow_logs[each.key].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.vpc[each.key].id
  tags = merge(
    var.tags,
    {
      Name = "${each.value.name}-flow-log"
    }
  )
}

resource "aws_cloudwatch_log_group" "local_flow_logs" {
  for_each          = { for k, v in var.vpcs : k => v if try(v.enable_flow_logs, false) }
  name              = "vpc-flow-logs/${each.value.name}"
  retention_in_days = each.value.log_retention_days
}

resource "aws_iam_role" "local_flow_log_role" {
  for_each = { for k, v in var.vpcs : k => v if try(v.enable_flow_logs, false) }
  name     = substr("fl-${each.value.name}", 0, 64)

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = ""
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "logs_permissions" {
  for_each = { for k, v in var.vpcs : k => v if try(v.enable_flow_logs, false) }
  name     = "flow-logs-policy-${each.value.name}"
  role     = aws_iam_role.local_flow_log_role[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:CreateLogDelivery",
          "logs:DeleteLogDelivery",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:${var.region}:*:log-group:vpc-flow-logs*"
      }
    ]
  })

}