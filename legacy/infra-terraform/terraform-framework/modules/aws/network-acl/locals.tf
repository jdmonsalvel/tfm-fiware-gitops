locals {
  acl_rules = flatten([
    for idx, acl in var.network_acls : [
      for rule_key, rule_value in acl.rules : {
        network_acl_name = idx
        vpc_name         = acl.vpc_name
        rule_number      = rule_value.rule_number
        egress           = rule_value.type == "inbound" ? false : true
        protocol         = rule_value.protocol
        rule_action      = rule_value.rule_action
        cidr_block       = rule_value.cidr_block
        from_port        = rule_value.from_port
        to_port          = rule_value.to_port
        icmp_type        = rule_value.icmp_type
        icmp_code        = rule_value.icmp_code
      }
    ]
  ])
}