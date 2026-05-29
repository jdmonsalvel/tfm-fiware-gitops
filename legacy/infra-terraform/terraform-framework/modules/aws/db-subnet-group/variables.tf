variable "db_subnet_ids" {
  description = "List of subnet IDs to include in the DB subnet group (subnets with db_subnet = true)"
  type        = list(string)
  default     = []
}

variable "name" {
  description = "Name for the DB subnet group"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
