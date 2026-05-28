resource "aws_db_instance" "rds" {
  for_each = var.rds_instances

  identifier     = each.value.name
  engine         = each.value.engine
  engine_version = each.value.engine_version
  instance_class = each.value.instance_class
  db_name        = each.value.db_name
  username       = each.value.username

  manage_master_user_password = each.value.manage_master_user_password

  multi_az              = each.value.multi_az
  allocated_storage     = each.value.allocated_storage
  max_allocated_storage = each.value.max_allocated_storage
  storage_type          = each.value.storage_type
  storage_encrypted     = each.value.storage_encrypted

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [for sg in each.value.security_group_names : var.security_group_ids[sg]]

  backup_retention_period = each.value.backup_retention_period
  deletion_protection     = each.value.deletion_protection
  skip_final_snapshot     = each.value.skip_final_snapshot

  parameter_group_name                = each.value.parameter_group_name
  option_group_name                   = each.value.option_group_name
  maintenance_window                  = each.value.maintenance_window
  backup_window                       = each.value.backup_window
  publicly_accessible                 = each.value.publicly_accessible
  iam_database_authentication_enabled = each.value.iam_database_authentication
  performance_insights_enabled        = each.value.performance_insights_enabled
  enabled_cloudwatch_logs_exports     = each.value.enabled_cloudwatch_logs_exports
  auto_minor_version_upgrade          = each.value.auto_minor_version_upgrade
  apply_immediately                   = each.value.apply_immediately

  tags = merge(
    var.tags,
    each.value.tags,
    { Name = each.value.name }
  )
}
