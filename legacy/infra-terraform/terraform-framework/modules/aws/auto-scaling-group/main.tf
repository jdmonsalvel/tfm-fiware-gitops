resource "aws_lb" "this" {
  for_each           = var.autoscaling_groups
  name               = "${each.value.name}-alb"
  internal           = each.value.alb_internal
  load_balancer_type = "application"
  security_groups    = each.value.alb_security_groups != null ? flatten([for sg_name in each.value.alb_security_groups : [for k, v in var.security_groups : v if can(regex(sg_name, k))]]) : []
  subnets            = flatten([for alb_sn_name in each.value.alb_subnets : [for k, v in var.subnets : v if can(regex(alb_sn_name, k))]])
  region             = var.region
  tags = merge(each.value.tags, {
    Name = "${each.value.name}-alb"
  })
}

resource "aws_lb_target_group" "this" {
  for_each = var.autoscaling_groups
  region   = var.region
  name     = "${each.value.name}-tg"
  port     = each.value.listener_port_http
  protocol = "HTTP"
  vpc_id   = var.vpc_ids[each.value.vpc_name]

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = each.value.health_check_path
    matcher             = "200-399"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  # Stickiness: soportado solo lb_cookie en ALB TG
  dynamic "stickiness" {
    for_each = each.value.stickiness_type == "lb_cookie" ? [true] : []
    content {
      type            = "lb_cookie"
      cookie_duration = each.value.stickiness_duration
      enabled         = true
    }
  }

  tags = merge(each.value.tags, {
    Name = "${each.value.name}-tg"
  })
}

resource "aws_lb_listener" "http" {
  for_each          = var.autoscaling_groups
  load_balancer_arn = aws_lb.this[each.key].arn
  port              = each.value.listener_port_http
  protocol          = "HTTP"
  region            = var.region
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.key].arn
  }
}

resource "aws_lb_listener" "https" {
  for_each          = { for k, cfg in var.autoscaling_groups : k => cfg if cfg.certificate_arn != null }
  region            = var.region
  load_balancer_arn = aws_lb.this[each.key].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = each.value.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.key].arn
  }
}

resource "aws_launch_template" "this" {
  for_each               = var.autoscaling_groups
  region                 = var.region
  name                   = "${each.value.name}-lt"
  image_id               = each.value.ami_id
  instance_type          = each.value.instance_type
  key_name               = each.value.key_pair != null && contains(keys(var.keypairs), each.value.key_pair) ? var.keypairs[each.value.key_pair] : null
  vpc_security_group_ids = flatten([for sg_name in each.value.instances_security_groups : [for k, v in var.security_groups : v if can(regex(sg_name, k))]])

  user_data = try(each.value.user_data_base64, null)

  metadata_options {
    http_tokens                 = each.value.imdsv2_required ? "required" : "optional"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = each.value.ebs_volume_size
      volume_type           = each.value.ebs_volume_type
      encrypted             = each.value.ebs_encrypted
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(each.value.tags, {
      Name = "${each.value.name}-instance"
    })
  }

  tags = merge(each.value.tags, {
    Name = "${each.value.name}-lt"
  })
}

resource "aws_autoscaling_group" "this" {
  for_each            = var.autoscaling_groups
  region              = var.region
  name                = "${each.value.name}-asg"
  desired_capacity    = each.value.desired_capacity
  min_size            = each.value.min_size
  max_size            = each.value.max_size
  vpc_zone_identifier = flatten([for sn_name in each.value.instance_subnets : [for k, v in var.subnets : v if can(regex(sn_name, k))]])

  target_group_arns = [aws_lb_target_group.this[each.key].arn]

  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.this[each.key].id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(each.value.tags, { Name = "${each.value.name}-asg" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}


locals {
  scaling_enabled = { for k, cfg in var.autoscaling_groups : k => cfg if cfg.policy_enabled }
}

resource "aws_autoscaling_policy" "scale_up" {
  for_each               = local.scaling_enabled
  region                 = var.region
  name                   = "${each.value.name}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.this[each.key].name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = each.value.scale_up_adjustment
  cooldown               = 60
}

resource "aws_autoscaling_policy" "scale_down" {
  for_each               = local.scaling_enabled
  name                   = "${each.value.name}-scale-down"
  region                 = var.region
  autoscaling_group_name = aws_autoscaling_group.this[each.key].name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = each.value.scale_down_adjustment
  cooldown               = 60
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  for_each            = local.scaling_enabled
  alarm_name          = "${each.value.name}-high-cpu"
  region              = var.region
  alarm_description   = "Scale up on high CPU utilization"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  comparison_operator = "GreaterThanThreshold"
  threshold           = each.value.scale_up_threshold
  evaluation_periods  = 2
  period              = 60
  statistic           = "Average"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this[each.key].name
  }

  alarm_actions = [aws_autoscaling_policy.scale_up[each.key].arn]
  ok_actions    = []
  tags = merge(each.value.tags, {
    Name = "${each.value.name}-high-cpu"
  })
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  for_each            = local.scaling_enabled
  alarm_name          = "${each.value.name}-low-cpu"
  region              = var.region
  alarm_description   = "Scale down on low CPU utilization"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  comparison_operator = "LessThanThreshold"
  threshold           = each.value.scale_down_threshold
  evaluation_periods  = 2
  period              = 60
  statistic           = "Average"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this[each.key].name
  }

  alarm_actions = [aws_autoscaling_policy.scale_down[each.key].arn]
  ok_actions    = []
  tags = merge(each.value.tags, {
    Name = "${each.value.name}-low-cpu"
  })
}
