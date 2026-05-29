output "alb_arns" {
  description = "Map of ASG name to ALB ARN"
  value       = { for k, lb in aws_lb.this : k => lb.arn }
}

output "alb_dns_names" {
  description = "Map of ASG name to ALB DNS name"
  value       = { for k, lb in aws_lb.this : k => lb.dns_name }
}

output "target_group_arns" {
  description = "Map of ASG name to Target Group ARN"
  value       = { for k, tg in aws_lb_target_group.this : k => tg.arn }
}

output "autoscaling_group_arns" {
  description = "Map of ASG name to Auto Scaling Group ARN"
  value       = { for k, asg in aws_autoscaling_group.this : k => asg.arn }
}

output "autoscaling_group_names" {
  description = "Map of ASG name to Auto Scaling Group name"
  value       = { for k, asg in aws_autoscaling_group.this : k => asg.name }
}

output "launch_template_ids" {
  description = "Map of ASG name to Launch Template ID"
  value       = { for k, lt in aws_launch_template.this : k => lt.id }
}
