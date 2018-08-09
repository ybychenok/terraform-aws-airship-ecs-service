locals {
  # We only create when var.create is true and a LB ARN is given
  create = "${(var.create && length(var.lb_arn) > 0 ) ? true : false }"
}

data "aws_route53_zone" "selected" {
  count   = "${(local.create && var.create_route53_record ) ? 1 : 0 }"
  zone_id = "${var.route53_zone_id}"
}

data "aws_lb" "main" {
  count = "${local.create ? 1 : 0}"
  arn   = "${var.lb_arn}"
}

## Route53 DNS Record
resource "aws_route53_record" "record" {
  count   = "${(local.create && var.create_route53_record ) ? 1 : 0 }"
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = "${var.route53_name}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${data.aws_lb.main.dns_name}"]
}

##
## aws_lb_target_group inside the ECS Task will be created when the service is not the default forwarding service
## It will not be created when the service is not attached to a load balancer like a worker
resource "aws_lb_target_group" "service" {
  count                = "${local.create ? 1 : 0 }"
  name                 = "${var.cluster_name}-${var.name}"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = "${var.lb_vpc_id}"
  target_type          = "${var.target_type}"
  deregistration_delay = "${var.deregistration_delay}"

  health_check {
    path                = "${var.health_uri}"
    unhealthy_threshold = "${var.unhealthy_threshold}"
  }
}

##
## An aws_lb_listener_rule will only be created when a service has a load balancer attached
resource "aws_lb_listener_rule" "host_based_routing" {
  count = "${local.create && var.create_route53_record ? 1 : 0 }"

  listener_arn = "${var.lb_listener_arn}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.service.arn}"
  }

  condition {
    field  = "host-header"
    values = ["${join("",aws_route53_record.record.*.fqdn)}"]
  }
}

##
## An aws_lb_listener_rule will only be created when a service has a load balancer attached
resource "aws_lb_listener_rule" "host_based_routing_ssl" {
  count = "${local.create && var.https_enabled && var.create_route53_record? 1 : 0 }"

  listener_arn = "${var.lb_listener_arn_https}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.service.arn}"
  }

  condition {
    field  = "host-header"
    values = ["${join("",aws_route53_record.record.*.fqdn)}"]
  }
}

data "template_file" "custom_listen_host" {
  count = "${length(var.custom_listen_hosts)}"

  template = "$${listen_host}"

  vars {
    listen_host = "${var.custom_listen_hosts[count.index]}"
  }
}

##
## An aws_lb_listener_rule will only be created when a service has a load balancer attached
resource "aws_lb_listener_rule" "host_based_routing_custom_listen_host" {
  count = "${local.create && length(var.custom_listen_hosts) > 0 ? length(var.custom_listen_hosts) : 0 }"

  listener_arn = "${var.lb_listener_arn}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.service.arn}"
  }

  condition {
    field  = "host-header"
    values = ["${data.template_file.custom_listen_host.*.rendered[count.index]}"]
  }
}

##
## An aws_lb_listener_rule will only be created when a service has a load balancer attached
resource "aws_lb_listener_rule" "host_based_routing_ssl_custom_listen_host" {
  count = "${local.create && length(var.custom_listen_hosts) > 0 ? length(var.custom_listen_hosts) : 0 }"

  listener_arn = "${var.lb_listener_arn_https}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.service.arn}"
  }

  condition {
    field  = "host-header"
    values = ["${data.template_file.custom_listen_host.*.rendered[count.index]}"]
  }
}

# This is an output the ecs_service depends on. This to make sure the target_group is attached to an alb before adding to a service. The actual content is useless
output "aws_lb_listener_rules" {
  value = ["${concat(aws_lb_listener_rule.host_based_routing.*.arn,aws_lb_listener_rule.host_based_routing_custom_listen_host.*.arn, list())}"]
}
