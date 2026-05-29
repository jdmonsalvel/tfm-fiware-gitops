locals {
  hub_template_url   = "https://solutions-reference.s3.amazonaws.com/instance-scheduler-on-aws/latest/instance-scheduler-on-aws.template"
  spoke_template_url = "https://solutions-reference.s3.amazonaws.com/instance-scheduler-on-aws/latest/instance-scheduler-on-aws-remote.template"

  hubs   = { for k, v in var.instance_schedulers : k => v if v.role == "hub" }
  spokes = { for k, v in var.instance_schedulers : k => v if v.role == "spoke" }

  # ── Periods aplanados para for_each de DynamoDB ─────────────────────────────
  all_periods = merge([
    for hub_key, hub in local.hubs : {
      for period_key, period in hub.periods :
      "${hub_key}__${period_key}" => {
        hub_key     = hub_key
        period_name = period_key
        begintime   = period.begintime
        endtime     = period.endtime
        weekdays    = period.weekdays
        months      = period.months
        monthdays   = period.monthdays
      }
    }
  ]...)

  # ── Schedules aplanados para for_each de DynamoDB ───────────────────────────
  all_schedules = merge([
    for hub_key, hub in local.hubs : {
      for schedule_key, schedule in hub.schedules :
      "${hub_key}__${schedule_key}" => {
        hub_key            = hub_key
        schedule_name      = schedule_key
        periods            = schedule.periods
        timezone           = coalesce(schedule.timezone, hub.default_timezone)
        description        = schedule.description
        stop_new_instances = schedule.stop_new_instances
      }
    }
  ]...)

  # ── Asociaciones EC2: (hub, schedule, name-tag) ─────────────────────────────
  ec2_associations = merge([
    for hub_key, hub in local.hubs : merge([
      for schedule_key, schedule in hub.schedules : {
        for ec2_name in schedule.compute_resources.ec2 :
        "${hub_key}__${schedule_key}__${ec2_name}" => {
          hub_key       = hub_key
          schedule_name = schedule_key
          resource_name = ec2_name
          tag_key       = hub.tag_name
        }
      }
    ]...)
  ]...)

  # ── Asociaciones RDS: (hub, schedule, db-identifier) ─────────────────────────
  rds_associations = merge([
    for hub_key, hub in local.hubs : merge([
      for schedule_key, schedule in hub.schedules : {
        for rds_name in schedule.compute_resources.rds :
        "${hub_key}__${schedule_key}__${rds_name}" => {
          hub_key       = hub_key
          schedule_name = schedule_key
          resource_name = rds_name
          tag_key       = hub.tag_name
        }
      }
    ]...)
  ]...)

  # ── Tabla DynamoDB del hub — v3 devuelve ARN, extraemos el nombre ───────────
  hub_config_tables = {
    for k in keys(local.hubs) :
    k => try(split("/", lookup(aws_cloudformation_stack.hub[k].outputs, "ConfigurationTable", ""))[1], "")
  }

  # ── Flatten EC2 IDs desde los data sources (instancia puede tener varios IDs)
  ec2_tag_assignments = merge([
    for assoc_key, assoc in local.ec2_associations : {
      for instance_id in try(data.aws_instances.scheduled[assoc_key].ids, []) :
      "${assoc_key}__${instance_id}" => {
        instance_id   = instance_id
        tag_key       = assoc.tag_key
        schedule_name = assoc.schedule_name
      }
    }
  ]...)
}
