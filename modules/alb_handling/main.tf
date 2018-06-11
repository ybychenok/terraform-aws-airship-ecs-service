variable "create" {
  default = true
}

locals {
  # We only craete when var.create is true and a LB ARN is given
  create_as_count = "${(var.create == true ? 1 : 0 ) * ( length(var.lb_arn) > 0 ? 1 : 0)}"
}

data "aws_route53_zone" "selected" {
  count   = "${local.create_as_count * ( var.create_route53_zone == true ? 1 : 0 )}"
  zone_id = "${var.route53_zone_id}"
}

data "aws_lb" "main" {
  count = "${local.create_as_count}"
  arn   = "${var.lb_arn}"
}

## Route53 DNS Record
resource "aws_route53_record" "record" {
  count   = "${local.create_as_count * ( var.create_route53_record == true ? 1 : 0 )}"
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
  count       = "${local.create_as_count}"
  name        = "${var.cluster_name}-${var.name}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "${var.lb_vpc_id}"
  target_type = "${var.target_type}"

  health_check {
    path                = "${var.health_uri}"
    unhealthy_threshold = "${var.unhealthy_threshold}"
  }
}

##
## An aws_lb_listener_rule will only be created when a service has a load balancer attached
resource "aws_lb_listener_rule" "host_based_routing" {
  count = "${local.create_as_count}"

  listener_arn = "${var.lb_listener_arn}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.service.arn}"
  }

  condition {
    field  = "host-header"
    values = ["${compact(list((var.create_route53_zone ? join("",aws_route53_record.record.*.fqdn) : ""),var.custom_listen_host))}"]
  }
}

##
## An aws_lb_listener_rule will only be created when a service has a load balancer attached
resource "aws_lb_listener_rule" "host_based_routing-ssl" {
  count = "${local.create_as_count}"

  listener_arn = "${var.lb_listener_arn_https}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.service.arn}"
  }

  condition {
    field  = "host-header"
    values = ["${compact(list((var.create_route53_zone ? join("",aws_route53_record.record.*.fqdn) : ""),var.custom_listen_host))}"]
  }
}

output "lb_target_group_arn" {
  value = "${join("",aws_lb_target_group.service.*.arn)}"
}
