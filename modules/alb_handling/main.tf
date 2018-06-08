variable "route53_zone_id" {
  default = ""
}

variable "route53_name" {
  default = ""
}

variable "awsvpc_enabled" {
  default = false
}
variable "unhealthy_threshold" {
  default = ""
}

variable "name" {
  default = ""
}

variable "lb_arn" {
  default = ""
}

variable "lb_vpc_id" {
  default = ""
}

variable "aws_vpc_enabled" {
  default = false
}

variable "health_uri" {
  default = ""
}

variable "create_route53_zone" {
  default = true
}

variable "custom_listen_host" {
  default = ""
}

variable "create" {
  default = true
}

local {
  # We only craete when var.create is true and a LB ARN is given
  create = "${var.create * ( length(var.lb_arn) > 0 ? 1 : 0)}"
}

output "create" {
  value = "${local.create}"
}

data "aws_route53_zone" "selected" {
  count   = "${(local.create == true ? 1 : 0) * ( var.create_route53_zone == true ? 1 : 0 )}"
  zone_id = "${var.route53_zone_id}"
}

data "aws_lb" "main" {
  count = "${var.create}"
  arn   = "${var.lb_arn}"
}

## Route53 DNS Record
resource "aws_route53_record" "record" {
  count   = "${(local.create == true ? 1 : 0) * ( var.create_route53_zone == true ? 1 : 0 )}"
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
  count       = "${local.create}"
  name        = "${local.cluster_name}-${var.name}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "${var.lb_vpc_id}"
  target_type = "${var.awsvpc_enabled == 1 ? "ip" : "instance"}"

  health_check {
    path                = "${var.health_uri}"
    unhealthy_threshold = "${var.unhealthy_threshold}"
  }
}

##
## An aws_lb_listener_rule will only be created when a service has a load balancer attached
resource "aws_lb_listener_rule" "host_based_routing" {
  count = "${local.create}"

  listener_arn = "${local.lb_listener_arn}"

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
  count = "${local.create}"

  listener_arn = "${local.lb_listener_arn_https}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.service.arn}"
  }

  condition {
    field  = "host-header"
    values = ["${compact(list((var.create_route53_zone ? join("",aws_route53_record.record.*.fqdn) : ""),var.custom_listen_host))}"]
  }
}
