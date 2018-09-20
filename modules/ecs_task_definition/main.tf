locals {
  # Should be simplified after post Terraform 0.12 refactor
  container_cpu   = "${lookup(var.container_properties[0], "cpu", "")}"
  container_name  = "${lookup(var.container_properties[0], "name")}"
  container_image = "${lookup(var.container_properties[0], "image_url")}"

  container_memory             = "${lookup(var.container_properties[0], "memory", "")}"
  container_memory_reservation = "${lookup(var.container_properties[0], "memory_reservation", "")}"
  container_port               = "${lookup(var.container_properties[0], "port", "")}"
  docker_volume_name           = "${lookup(var.docker_volume, "name", "")}"

  safe_search_replace_string = "random460d168ecd774089a8f31b6dfde9285b"
}

resource "null_resource" "envvars_as_list_of_maps" {
  count = "${length(keys(var.container_envvars))}"

  triggers = "${map(
    "name", "${element(keys(var.container_envvars), count.index)}",
    "value", "${local.safe_search_replace_string}${element(values(var.container_envvars), count.index)}",
  )}"
}

module "container_definition" {
  source          = "../ecs_container_definition/"
  container_name  = "${var.name}"
  container_image = "${local.container_image}"

  container_cpu                = "${local.container_cpu}"
  container_memory             = "${local.container_memory}"
  container_memory_reservation = "${local.container_memory_reservation}"

  container_port = "${local.container_port}"
  host_port      = "${var.awsvpc_enabled ? local.container_port : "" }"

  hostname = "${var.awsvpc_enabled == 1 ? "" : var.name}"

  environment = ["${null_resource.envvars_as_list_of_maps.*.triggers}"]
  mountPoints = ["${var.mountpoints}"]

  log_options = {
    "awslogs-region"        = "${var.region}"
    "awslogs-group"         = "${var.cloudwatch_loggroup_name}"
    "awslogs-stream-prefix" = "${var.name}"
  }
}

resource "aws_ecs_task_definition" "app" {
  count = "${(var.create && (local.docker_volume_name == "")) ? 1 : 0 }"

  family        = "${var.name}"
  task_role_arn = "${var.ecs_taskrole_arn}"

  # Execution role ARN can be needed inside FARGATE
  execution_role_arn = "${var.ecs_task_execution_role_arn}"

  cpu    = "${var.fargate_enabled  ? lookup(var.container_properties[0], "cpu"): "" }"
  memory = "${var.fargate_enabled  ? lookup(var.container_properties[0], "mem"): "" }"

  # This is a hack: https://github.com/hashicorp/terraform/issues/14037#issuecomment-361202716
  # Specifically, we are assigning a list of maps to the `volume` block to
  # mimic multiple `volume` statements
  # This WILL break in Terraform 0.12: https://github.com/hashicorp/terraform/issues/14037#issuecomment-361358928
  # but we need something that works before then
  volume = ["${var.host_path_volumes}"]

  container_definitions = "${replace(module.container_definition.json,local.safe_search_replace_string,"")}"
  network_mode          = "${var.awsvpc_enabled ? "awsvpc" : "bridge"}"

  # We need to ignore future container_definitions, and placement_constraints, as other tools take care of updating the task definition
  lifecycle {
    ignore_changes = ["container_definitions", "placement_constraints"]
  }

  requires_compatibilities = ["${var.launch_type}"]
}

resource "aws_ecs_task_definition" "app_with_docker_volume" {
  count = "${(var.create && (local.docker_volume_name != "")) ? 1 : 0 }"

  family        = "${var.name}"
  task_role_arn = "${var.ecs_taskrole_arn}"

  # Execution role ARN can be needed inside FARGATE
  execution_role_arn = "${var.ecs_task_execution_role_arn}"

  cpu    = "${var.fargate_enabled  ? lookup(var.container_properties[0], "cpu"): "" }"
  memory = "${var.fargate_enabled  ? lookup(var.container_properties[0], "mem"): "" }"

  # This is a hack: https://github.com/hashicorp/terraform/issues/14037#issuecomment-361202716
  # Specifically, we are assigning a list of maps to the `volume` block to
  # mimic multiple `volume` statements
  # This WILL break in Terraform 0.12: https://github.com/hashicorp/terraform/issues/14037#issuecomment-361358928
  # but we need something that works before then
  volume = ["${var.host_path_volumes}"]

  # Unfortunately, the same hack doesn't work for a list of Docker volume
  # blocks because they include a nested map; therefore the only way to
  # currently sanely support Docker volume blocks is to only consider the
  # single volume case.
  volume = {
    name = "${local.docker_volume_name}"

    docker_volume_configuration {
      autoprovision = "${lookup(var.docker_volume, "autoprovision", false)}"
      scope         = "${lookup(var.docker_volume, "scope", "shared")}"
      driver        = "${lookup(var.docker_volume, "driver", "")}"
    }
  }

  container_definitions = "${replace(module.container_definition.json,local.safe_search_replace_string,"")}"
  network_mode          = "${var.awsvpc_enabled ? "awsvpc" : "bridge"}"

  # We need to ignore future container_definitions, and placement_constraints, as other tools take care of updating the task definition
  lifecycle {
    ignore_changes = ["container_definitions", "placement_constraints"]
  }

  requires_compatibilities = ["${var.launch_type}"]
}
