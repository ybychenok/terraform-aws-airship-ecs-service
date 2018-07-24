locals {
  awsvpc_enabled = "${length(var.awsvpc_subnets) > 0 ? true : false }"
  lb_attached    = "${var.lb_attached}"
}

# Make an LB connected service dependent of this rule
# This to make sure the Target Group is linked to a Load Balancer before the aws_ecs_service is created
resource "null_resource" "aws_lb_listener_rules" {
  count = "${var.create && local.lb_attached ? 1 : 0}"

  triggers {
    listeners = "${join(",", var.aws_lb_listener_rules)}"
  }
}

resource "aws_ecs_service" "app_with_lb_awsvpc" {
  count = "${var.create && local.awsvpc_enabled && local.lb_attached ? 1 : 0}"

  name            = "${var.name}"
  cluster         = "${var.cluster_id}"
  task_definition = "${var.ecs_task_definition_arn}"

  desired_count       = "${var.desired_capacity}"
  launch_type         = "${var.launch_type}"
  scheduling_strategy = "${var.scheduling_strategy}"

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

  depends_on = ["null_resource.aws_lb_listener_rules"]
}

resource "aws_ecs_service" "app_with_lb_spread" {
  count           = "${var.create && !local.awsvpc_enabled && local.lb_attached && var.with_placement_strategy ? 1 : 0}"
  name            = "${var.name}"
  launch_type     = "${var.launch_type}"
  cluster         = "${var.cluster_id}"
  task_definition = "${var.ecs_task_definition_arn}"

  desired_count       = "${var.desired_capacity}"
  scheduling_strategy = "${var.scheduling_strategy}"

  deployment_maximum_percent         = "${var.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"

  ordered_placement_strategy {
     field = "attribute:ecs.availability-zone"
     type  = "spread"
   }
 
   ordered_placement_strategy {
     field = "instanceId"
     type  = "spread"
   }
 
   ordered_placement_strategy {
     field = "memory"
     type  = "binpack"
   }

  load_balancer {
    target_group_arn = "${var.lb_target_group_arn}"
    container_name   = "${var.container_name}"
    container_port   = "${var.container_port}"
  }

  lifecycle {
    ignore_changes = ["desired_count", "task_definition", "revision"]
  }

  depends_on = ["null_resource.aws_lb_listener_rules"]
}

resource "aws_ecs_service" "app_with_lb" {
  count           = "${var.create && !local.awsvpc_enabled && local.lb_attached && !var.with_placement_strategy ? 1 : 0}"
  name            = "${var.name}"
  launch_type     = "${var.launch_type}"
  cluster         = "${var.cluster_id}"
  task_definition = "${var.ecs_task_definition_arn}"

  desired_count       = "${var.desired_capacity}"
  scheduling_strategy = "${var.scheduling_strategy}"

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

  depends_on = ["null_resource.aws_lb_listener_rules"]
}

resource "aws_ecs_service" "app" {
  count = "${var.create && ! local.lb_attached && ! local.awsvpc_enabled ? 1 : 0 }"

  name                = "${var.name}"
  launch_type         = "${var.launch_type}"
  scheduling_strategy = "${var.scheduling_strategy}"
  cluster             = "${var.cluster_id}"
  task_definition     = "${var.ecs_task_definition_arn}"
  desired_count       = "${var.desired_capacity}"

  deployment_maximum_percent         = "${var.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"

  lifecycle {
    ignore_changes = ["desired_count", "task_definition"]
  }
}

resource "aws_ecs_service" "app_awsvpc" {
  count = "${var.create && ! local.lb_attached && local.awsvpc_enabled ? 1 : 0 }"

  name                = "${var.name}"
  launch_type         = "${var.launch_type}"
  scheduling_strategy = "${var.scheduling_strategy}"
  cluster             = "${var.cluster_id}"
  task_definition     = "${var.ecs_task_definition_arn}"
  desired_count       = "${var.desired_capacity}"

  deployment_maximum_percent         = "${var.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"

  network_configuration {
    subnets         = ["${var.awsvpc_subnets}"]
    security_groups = ["${var.awsvpc_security_group_ids}"]
  }

  lifecycle {
    ignore_changes = ["desired_count", "task_definition"]
  }
}
