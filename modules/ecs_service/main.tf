variable "name" {}

variable "create" {
  default = true
}

variable "cluster_id" {}
variable "ecs_task_definition_arn" {}
variable "launch_type" {}

variable "desired_capacity" {}
variable "container_name" {}
variable "container_port" {}
variable "deployment_maximum_percent" {}
variable "deployment_minimum_healthy_percent" {}

variable "awsvpc_subnets" {
  default = []
}

variable "awsvpc_security_group_ids" {
  default = []
}

variable "lb_create" {}

variable "lb_target_group_arn" {
  default = ""
}

locals {
  awsvpc_enabled = "${length(var.awsvpc_subnets) > 0 ? 1 : 0 }"
}

resource "aws_ecs_service" "app-with-lb-awsvpc" {
  count = "${var.create * ( local.awsvpc_enabled * (var.lb_create == 1 ? 1 : 0))}"

  name            = "${var.name}"
  cluster         = "${var.cluster_id}"
  task_definition = "${var.ecs_task_definition_arn}"

  desired_count = "${var.desired_capacity}"
  launch_type   = "${var.launch_type}"

  deployment_maximum_percent         = "${var.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"

  load_balancer {
    target_group_arn = "${var.lb_target_group_arn}"
    container_name   = "${var.container_name}"
    container_port   = "${var.container_port}"
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
  count           = "${var.create * ( (local.awsvpc_enabled == 0 ? 1 : 0 ) * (var.lb_create == 1 ? 1 : 0))}"
  name            = "${var.name}"
  launch_type     = "${var.launch_type}"
  cluster         = "${var.cluster_id}"
  task_definition = "${var.ecs_task_definition_arn}"

  desired_count = "${var.desired_capacity}"

  deployment_maximum_percent         = "${local.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${local.deployment_minimum_healthy_percent}"

  load_balancer {
    target_group_arn = "${var.lb_target_group_arn}"
    container_name   = "${var.container_name}"
    container_port   = "${var.container_port}"
  }

  lifecycle {
    ignore_changes = ["desired_count", "task_definition", "revision"]
  }
}

resource "aws_ecs_service" "app" {
  count = "${var.create * ( 1 - var.lb_create)}"

  name            = "${var.name}"
  launch_type     = "${var.launch_type}"
  cluster         = "${var.cluster_id}"
  task_definition = "${var.ecs_task_definition_arn}"
  desired_count   = "${var.desired_capacity}"

  lifecycle {
    ignore_changes = ["desired_count", "task_definition"]
  }
}

output "ecs_service_name" {
  value = "${var.create ? local.awsvpc_enabled ? join("",aws_ecs_service.app-with-lb-awsvpc.*.name) : join("",aws_ecs_service.app-with-lb.*.name): "" }"
}
