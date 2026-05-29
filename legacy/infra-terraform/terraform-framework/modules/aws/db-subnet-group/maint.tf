resource "aws_db_subnet_group" "db_subnet_group" {
  count      = length(var.db_subnet_ids) > 0 ? 1 : 0
  name       = lower(var.name)
  subnet_ids = var.db_subnet_ids

  tags = merge(
    var.tags,
    { Name = lower(var.name) }
  )
}
