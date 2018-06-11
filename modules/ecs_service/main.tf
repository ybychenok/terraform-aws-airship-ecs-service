locals {
  awsvpc_enabled = "${length(var.awsvpc_subnets) > 0 ? true : false }"

  # not sure how to do a negation of a boolean
  awsvpc_disabled = "${length(var.awsvpc_subnets) > 0 ? false : true }"

  #
  lb_attached     = "${length(var.lb_target_group_arn) > 0 ? true :  false }"
  lb_not_attached = "${length(var.lb_target_group_arn) > 0 ? false :  true }"
}

resource "aws_ecs_service" "app_with_lb_awsvpc" {
  count = "${var.create && local.awsvpc_enabled && local.lb_attached ? 1 : 0}"

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

resource "aws_ecs_service" "app_with_lb" {
  count           = "${var.create && local.awsvpc_disabled && local.lb_attached ? 1 : 0}"
  name            = "${var.name}"
  launch_type     = "${var.launch_type}"
  cluster         = "${var.cluster_id}"
  task_definition = "${var.ecs_task_definition_arn}"

  desired_count = "${var.desired_capacity}"

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
}

resource "aws_ecs_service" "app" {
  count = "${var.create && local.lb_not_attached && local.awsvpc_disabled? 1 : 0 }"

  name            = "${var.name}"
  launch_type     = "${var.launch_type}"
  cluster         = "${var.cluster_id}"
  task_definition = "${var.ecs_task_definition_arn}"
  desired_count   = "${var.desired_capacity}"

  lifecycle {
    ignore_changes = ["desired_count", "task_definition"]
  }
}

resource "aws_ecs_service" "app_awsvpc" {
  count = "${var.create && local.lb_not_attached && local.awsvpc_enabled ? 1 : 0 }"

  name            = "${var.name}"
  launch_type     = "${var.launch_type}"
  cluster         = "${var.cluster_id}"
  task_definition = "${var.ecs_task_definition_arn}"
  desired_count   = "${var.desired_capacity}"

  lifecycle {
    ignore_changes = ["desired_count", "task_definition"]
  }
}

# We need to output the service name of the resource created
# Autoscaling uses the service name, by using the service name of the resource output, we make sure that the
# Order of creation is maintained
output "ecs_service_name" {
  value = "${local.awsvpc_enabled ? 
                ( local.lb_attached ? join("",aws_ecs_service.app_with_lb_awsvpc.*.name) : join("",aws_ecs_service.app_awsvpc.*.name) ) 
                :
                ( local.lb_attached ? join("",aws_ecs_service.app_with_lb.*.name) : join("",aws_ecs_service.app.*.name) ) 
  }"
}
