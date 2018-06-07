data "aws_region" "current" {}

data "aws_route53_zone" "selected" {
  zone_id = "${local.route53_zone_id}"
}

data "aws_lb" "main" {
  arn = "${local.lb_arn}"
}

data "aws_ecs_cluster" "this" {
  cluster_name = "${local.cluster_name}"
}

data "aws_caller_identity" "current" {}

## TODO Listeners as datasource, but in some cases there is not SSL Listener which would result in failure. Can only work when datasources can be conditionalised.

## LOCALS
locals {
  fargate_enabled = "${lookup(var.ecs_properties,"service_launch_type", "EC2") == "FARGATE" ? true : false }"
  launch_type     = "${local.fargate_enabled ? "FARGATE" : "EC2" }"

  cluster_name = "${lookup(var.ecs_properties,"ecs_cluster_name")}"
  cluster_id   = "${data.aws_ecs_cluster.this.arn}"

  awsvpc_enabled = "${var.awsvpc_enabled}"

  # For Fargate services the Service itself needs to have CPU defined
  fargate_memory = "${local.fargate_enabled == true ? lookup(var.ecs_properties,"memory") : ""}"
  fargate_cpu    = "${local.fargate_enabled == true ? lookup(var.ecs_properties,"cpu") : ""}"

  # Load balancer related properties
  lb_attached           = "${lookup(var.load_balancing_properties,"alb_attached", true)}"
  lb_arn                = "${lookup(var.load_balancing_properties,"lb_arn", "")}"
  lb_listener_arn       = "${lookup(var.load_balancing_properties,"lb_listener_arn", "")}"
  lb_listener_arn_https = "${lookup(var.load_balancing_properties,"lb_listener_arn_https", "")}"
  lb_priority           = "${lookup(var.load_balancing_properties,"lb_priority", 100)}"

  container_port = "${lookup(var.container_properties[0], "port")}"

  lb_vpc_id       = "${lookup(var.load_balancing_properties,"lb_vpc_id", "")}"
  route53_zone_id = "${lookup(var.load_balancing_properties,"route53_zone_id", "")}"
  route53_name    = "${var.name}.${data.aws_route53_zone.selected.name}"

  health_uri          = "${lookup(var.load_balancing_properties,"health_uri", "/ping")}"
  unhealthy_threshold = "${lookup(var.load_balancing_properties,"health_uri", "3")}"

  scaling_enabled      = "${length(var.scaling_properties) > 0 ? true : false }"
  desired_capacity     = "${lookup(var.capacity_properties,"desired_capacity", 2)}"
  desired_min_capacity = "${lookup(var.capacity_properties,"desired_min_capacity", 2)}"
  desired_max_capacity = "${lookup(var.capacity_properties,"desired_max_capacity", 2)}"
  deployment_maximum_percent = "${lookup(var.capacity_properties,"deployment_maximum_percent", 200)}"
  deployment_minimum_healthy_percent = "${lookup(var.capacity_properties,"deployment_minimum_healthy_percent", 0)}"
}

##
## aws_lb_target_group inside the ECS Task will be created when the service is not the default forwarding service
## It will not be created when the service is not attached to a load balancer like a worker

resource "aws_lb_target_group" "service" {
  name        = "${local.cluster_name}-${var.name}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "${local.lb_vpc_id}"
  target_type = "${local.awsvpc_enabled == 1 ? "ip" : "instance"}"

  health_check {
    path                = "${local.health_uri}"
    unhealthy_threshold = "${local.unhealthy_threshold}"
  }
}

##
## An aws_lb_listener_rule will only be created when a service has a load balancer attached
resource "aws_lb_listener_rule" "host_based_routing" {
  count = "${local.lb_attached == "1" ? 1 : 0}"

  listener_arn = "${local.lb_listener_arn}"
  priority     = "${local.lb_priority}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.service.arn}"
  }

  condition {
    field  = "host-header"
    values = ["${aws_route53_record.record.fqdn}"]
  }
}

##
## An aws_lb_listener_rule will only be created when a service has a load balancer attached
resource "aws_lb_listener_rule" "host_based_routing-ssl" {
  count = "${local.lb_attached == "1" ? 1 : 0}"

  listener_arn = "${local.lb_listener_arn_https}"
  priority     = "${local.lb_priority}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.service.arn}"
  }

  condition {
    field  = "host-header"
    values = ["${aws_route53_record.record.fqdn}"]
  }
}

## Route53 DNS Record

resource "aws_route53_record" "record" {
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = "${local.route53_name}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${data.aws_lb.main.dns_name}"]
}

data "template_file" "task_definition" {
  count = "${length(var.container_properties)}"

  template = "${file("${"${path.module}/task-definition.json"}")}"

  vars {
    image_url        = "${lookup(var.container_properties[count.index], "image_url")}"
    task_type        = "${lookup(var.container_properties[count.index], "task_type","")}"
    region           = "${data.aws_region.current.name}"
    cpu              = "${lookup(var.container_properties[count.index], "cpu")}"
    mem              = "${lookup(var.container_properties[count.index], "mem")}"
    envvars          = ""
    container_name   = "${local.cluster_name}-${var.name}"
    container_port   = "${local.container_port}"
    host_port        = "${var.awsvpc_enabled == 1 ? local.container_port : "0" }"
    discovery_name   = "${var.name}"
    hostname_block   = "${var.awsvpc_enabled == 0 ? "\"hostname\":\"${local.cluster_name}-${var.name}-${count.index}\",\n" :""}"
    log_group_region = "${data.aws_region.current.name}"
    log_group_name   = "${aws_cloudwatch_log_group.app.name}"
    log_group_stream = "${count.index}"
  }
}

resource "aws_ecs_task_definition" "app" {
  family        = "${var.name}"
  task_role_arn = "${aws_iam_role.ecs_tasks_role.arn}"

  # Execution role ARN can be needed inside FARGATE
  execution_role_arn = "${local.fargate_enabled ? join("",aws_iam_role.ecs_task_execution_role.*.arn) : "" }"

  cpu    = "${local.fargate_enabled     ? local.fargate_cpu : "" }"
  memory = "${local.fargate_enabled  ? local.fargate_memory : "" }"

  container_definitions = "[${join(",",data.template_file.task_definition.*.rendered)}]"
  network_mode          = "awsvpc"
  network_mode          = "${local.awsvpc_enabled == 1 ? "awsvpc" : "bridge"}"

  lifecycle {
    ignore_changes = ["container_definitions", "placement_constraints"]
  }

  requires_compatibilities = ["${local.launch_type}"]
}

resource "aws_ecs_service" "app-with-lb-awsvpc" {
  count = "${(local.awsvpc_enabled == 1 ? 1 : 0 ) * (local.lb_attached == 1 ? 1 : 0)}"

  name            = "${local.cluster_name}-${var.name}"
  cluster         = "${local.cluster_id}"
  task_definition = "${aws_ecs_task_definition.app.arn}"

  desired_count = "${local.desired_capacity}"
  launch_type   = "${local.fargate_enabled ? "FARGATE" : "EC2"}"

  deployment_maximum_percent         = "${local.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${local.deployment_minimum_healthy_percent}"

  load_balancer {
    target_group_arn = "${aws_lb_target_group.service.id}"
    container_name   = "${local.cluster_name}-${var.name}"
    container_port   = "${local.container_port}"
  }

  lifecycle {
    ignore_changes = ["desired_count", "task_definition", "revision"]
  }

  network_configuration {
    subnets         = ["${var.awsvpc_subnets}"]
    security_groups = ["${var.awsvpc_security_group_ids}"]
  }
}

resource "aws_ecs_service" "app-with-lb" {
  count           = "${(var.awsvpc_enabled == 0 ? 1 : 0 ) * (local.lb_attached == 1 ? 1 : 0)}"
  name            = "${local.cluster_name}-${var.name}"
  launch_type     = "${local.launch_type}"
  cluster         = "${local.cluster_id}"
  task_definition = "${aws_ecs_task_definition.app.arn}"

  desired_count = "${local.desired_capacity}"

  deployment_maximum_percent         = "${local.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${local.deployment_minimum_healthy_percent}"

  load_balancer {
    target_group_arn = "${aws_lb_target_group.service.id}"
    container_name   = "${local.cluster_name}-${var.name}"
    container_port   = "${local.container_port}"
  }

  lifecycle {
    ignore_changes = ["desired_count", "task_definition", "revision"]
  }
}

resource "aws_ecs_service" "app" {
  count = "${1 - local.lb_attached}"

  name            = "${local.cluster_name}-${var.name}"
  launch_type     = "${local.launch_type}"
  cluster         = "${local.cluster_id}"
  task_definition = "${aws_ecs_task_definition.app.arn}"
  desired_count   = "${local.desired_capacity}"

  lifecycle {
    ignore_changes = ["desired_count", "task_definition"]
  }
}

###### CloudWatch Logs
resource "aws_cloudwatch_log_group" "app" {
  name              = "${local.cluster_name}/${var.name}"
  retention_in_days = 14
}
