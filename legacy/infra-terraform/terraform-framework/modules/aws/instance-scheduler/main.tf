# ──────────────────────────────────────────────────────────────────────────────
# HUB — despliega la solución Instance Scheduler (Lambda + DynamoDB + EventBridge)
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_cloudformation_stack" "hub" {
  for_each = local.hubs

  name         = "instance-scheduler-${each.key}"
  template_url = local.hub_template_url
  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]

  parameters = {
    Namespace                   = each.value.namespace
    TagName                     = each.value.tag_name
    DefaultTimezone             = each.value.default_timezone
    Regions                     = join(",", each.value.regions)
    SchedulingActive            = each.value.scheduling_active ? "Yes" : "No"
    SchedulerFrequency          = tostring(each.value.scheduler_frequency)
    CreateRdsSnapshot           = each.value.create_rds_snapshot ? "Yes" : "No"
    EnableSSMMaintenanceWindows = each.value.enable_ssm_maintenance_windows ? "Yes" : "No"
    EnableInformationalTagging  = each.value.enable_informational_tagging ? "Yes" : "No"
    RetainDataAndLogs           = each.value.retain_data_and_logs
    OpsMonitoring               = each.value.ops_monitoring
    MemorySize                  = tostring(each.value.memory_size)
    OrchestratorMemorySize      = tostring(each.value.orchestrator_memory_size)
    LogRetentionDays            = tostring(each.value.log_retention_days)
    Trace                       = each.value.trace ? "Yes" : "No"
    UsingAWSOrganizations       = "No"
    Principals                  = ""
  }

  tags = merge(var.tags, each.value.tags, {
    Name = "instance-scheduler-${each.key}"
    Role = "hub"
  })

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# SPOKE — cuenta gestionada (cross-account)
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_cloudformation_stack" "spoke" {
  for_each = local.spokes

  name         = "instance-scheduler-spoke-${each.key}"
  template_url = local.spoke_template_url
  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]

  parameters = {
    Namespace                = each.value.namespace
    InstanceSchedulerAccount = each.value.hub_account_id
    ScheduleTagKey           = each.value.tag_name
    UsingAWSOrganizations    = "No"
    Regions                  = join(",", each.value.regions)
  }

  tags = merge(var.tags, each.value.tags, {
    Name = "instance-scheduler-spoke-${each.key}"
    Role = "spoke"
  })

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# PERIODS — ventanas horarias escritas en la tabla DynamoDB del hub
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_dynamodb_table_item" "period" {
  for_each = local.all_periods

  table_name = local.hub_config_tables[each.value.hub_key]
  hash_key   = "type"
  range_key  = "name"

  item = jsonencode(merge(
    {
      type      = { S = "period" }
      name      = { S = each.value.period_name }
      begintime = { S = each.value.begintime }
      endtime   = { S = each.value.endtime }
    },
    length(each.value.weekdays) > 0 ? { weekdays = { SS = each.value.weekdays } } : {},
    length(each.value.months) > 0 ? { months = { SS = each.value.months } } : {},
    length(each.value.monthdays) > 0 ? { monthdays = { SS = each.value.monthdays } } : {}
  ))

  depends_on = [aws_cloudformation_stack.hub]
}

# ──────────────────────────────────────────────────────────────────────────────
# SCHEDULES — agrupan periods en DynamoDB
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_dynamodb_table_item" "schedule" {
  for_each = local.all_schedules

  table_name = local.hub_config_tables[each.value.hub_key]
  hash_key   = "type"
  range_key  = "name"

  item = jsonencode({
    type               = { S = "schedule" }
    name               = { S = each.value.schedule_name }
    periods            = { SS = each.value.periods }
    timezone           = { S = each.value.timezone }
    description        = { S = each.value.description }
    stop_new_instances = { BOOL = each.value.stop_new_instances }
  })

  depends_on = [aws_cloudformation_stack.hub]
}

# ──────────────────────────────────────────────────────────────────────────────
# ASOCIACIÓN EC2 — busca instancias por tag Name y aplica el tag de schedule
# ──────────────────────────────────────────────────────────────────────────────
data "aws_instances" "scheduled" {
  for_each = local.ec2_associations

  filter {
    name   = "tag:Name"
    values = [each.value.resource_name]
  }
  filter {
    name   = "instance-state-name"
    values = ["running", "stopped", "stopping", "pending"]
  }
}

resource "aws_ec2_tag" "schedule" {
  for_each = local.ec2_tag_assignments

  resource_id = each.value.instance_id
  key         = each.value.tag_key
  value       = each.value.schedule_name
}

# ──────────────────────────────────────────────────────────────────────────────
# ASOCIACIÓN RDS — busca instancias RDS por identifier y aplica el tag
# ──────────────────────────────────────────────────────────────────────────────
data "aws_db_instance" "scheduled" {
  for_each = local.rds_associations

  db_instance_identifier = each.value.resource_name
}

resource "aws_ec2_tag" "rds_schedule" {
  for_each = {
    for k, v in local.rds_associations :
    k => v if try(data.aws_db_instance.scheduled[k].db_instance_arn, "") != ""
  }

  resource_id = data.aws_db_instance.scheduled[each.key].db_instance_arn
  key         = each.value.tag_key
  value       = each.value.schedule_name
}
