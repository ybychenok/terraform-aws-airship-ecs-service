resource "null_resource" "envvars_as_list_of_maps" {
  count = "${length(keys(var.container_envvars))}"

  triggers = "${map(
    "name", "${element(keys(var.container_envvars), count.index)}",
    "value", "string:${element(values(var.container_envvars), count.index)}",
  )}"
}

module "container_definition" {
  source          = "../ecs_container_definition/"
  container_name  = "name"
  container_image = "cloudposse/geodesic"

  container_cpu                = "${var.container_cpu}"
  container_memory             = "${var.container_memory}"
  container_memory_reservation = "${var.container_memory_reservation}"

  container_port = "${var.container_port}"
  host_port      = "${var.awsvpc_enabled ? var.container_port : "0" }"

  hostname = "${var.awsvpc_enabled == 1 ? "" : var.name}"

  environment = ["${null_resource.envvars_as_list_of_maps.*.triggers}"]

  log_options = {
    "awslogs-region"        = "${var.region}"
    "awslogs-group"         = "${var.cloudwatch_loggroup_name}"
    "awslogs-stream-prefix" = "${var.name}"
  }
}

resource "aws_ecs_task_definition" "app" {
  count = "${var.create ? 1 : 0 }"

  family        = "${var.name}"
  task_role_arn = "${var.ecs_taskrole_arn}"

  # Execution role ARN can be needed inside FARGATE
  execution_role_arn = "${var.ecs_task_execution_role_arn}"

  cpu    = "${var.fargate_enabled  ? lookup(var.container_properties[0], "cpu"): "" }"
  memory = "${var.fargate_enabled  ? lookup(var.container_properties[0], "mem"): "" }"

  container_definitions = "[${join(",",data.template_file.task_definition.*.rendered)}]"
  network_mode          = "${var.awsvpc_enabled ? "awsvpc" : "bridge"}"

  # We need to ignore future container_definitions, and placement_constraints, as other tools take care of updating the task definition
  lifecycle {
    ignore_changes = ["container_definitions", "placement_constraints"]
  }

  requires_compatibilities = ["${var.launch_type}"]
}
