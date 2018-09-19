# When AWSVPC is enabled the hostport is equal to the container port, otherwise we can use dynamic port allocation
data "template_file" "portmapping" {
  vars {
    container_port = "${local.container0_port}"
    host_port      = "${var.awsvpc_enabled ? local.container0_port : "0" }"
  }

  template = <<EOF
"portMappings": [
      {
        "containerPort": $${container_port},
        "hostPort": $${host_port}
      }
    ],
EOF
}

data "template_file" "mountpoint" {
  count = "${length(var.mountpoints)}"

  vars {
    source_volume  = "${lookup(var.mountpoints[count.index], "source_volume")}"
    container_path = "${lookup(var.mountpoints[count.index], "container_path")}"
    read_only      = "${lookup(var.mountpoints[count.index], "read_only", "false")}"
  }

  template = <<EOF
{
	"sourceVolume": "$${source_volume}",
	"containerPath": "$${container_path}",
	"readOnly": $${read_only}
}
EOF
}

data "template_file" "mountpoints" {
  vars {
    values = "${join(",", data.template_file.mountpoint.*.rendered)}"
  }

  template = <<EOF
"mountPoints": [
    $${values}
    ],
EOF
}

locals {
  # container0_name is the name of the first container
  container0_name = "${lookup(var.container_properties[0], "name")}"

  # container0_name is the port of the first container
  container0_port = "${lookup(var.container_properties[0], "port", "")}"
}

# environment variables set to true are converted to 0 or 1 when it comes from a null_resource. We change the string and replace it later
# https://github.com/hashicorp/terraform/issues/13512
# we use the null_resource triggers to create a list of key value maps

variable "my_random" {
  default = "random460d168ecd774089a8f31b6dfde9285b"
}

resource "null_resource" "envvars_as_list_of_maps" {
  count = "${length(keys(var.container_envvars))}"

  triggers = "${map(
    "name", "${element(keys(var.container_envvars), count.index)}",
    "value", "${var.my_random}${element(values(var.container_envvars), count.index)}",
  )}"
}

data "template_file" "container_definition" {
  # We have as many container definitions per task as given maps inside the container properties variable
  count = "${var.create && length(var.container_properties) > 0 ? 1 : 0}"

  template = "${file("${"${path.module}/container-definition.json"}")}"

  vars {
    image_url = "${lookup(var.container_properties[count.index], "image_url")}"
    region    = "${var.region}"
    cpu       = "${lookup(var.container_properties[count.index], "cpu")}"
    mem       = "${lookup(var.container_properties[count.index], "mem")}"

    mem_reservation = "${lookup(var.container_properties[count.index], "mem_reservation", "null")}"

    # We remove the earlier prepended variable to mitigate https://github.com/hashicorp/terraform/issues/13512
    envvars = "${replace(jsonencode(null_resource.envvars_as_list_of_maps.*.triggers), var.my_random, "")}"

    # We only create a  portmapping  for the first container
    portmappings_block = "${count.index == 0 && local.container0_port != "" ? data.template_file.portmapping.rendered : ""}"

    container_name = "${lookup(var.container_properties[count.index], "name")}"

    # In non-awsvpc environments we can set the hostname
    hostname_block    = "${var.awsvpc_enabled == 0 ? "\"hostname\":\"${var.name}-${count.index}\",\n" :""}"
    mountpoints_block = "${data.template_file.mountpoints.rendered}"

    # Cloudwatch logging
    log_group_region = "${var.region}"
    log_group_name   = "${var.cloudwatch_loggroup_name}"
    log_group_stream = "${lookup(var.container_properties[count.index], "name")}"
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

  # This is a hack: https://github.com/hashicorp/terraform/issues/14037#issuecomment-361202716
  # Specifically, we are assigning a list of maps to the `volume` block to
  # mimic multiple `volume` statements
  # This WILL break in Terraform 0.12: https://github.com/hashicorp/terraform/issues/14037#issuecomment-361358928
  # but we need something that works before then
  volume = ["${var.host_path_volumes}"]

  # Unfortunately, our hack doesn't work for Docker volume blocks because they
  # include a nested map; therefore the only way to currently sanely support
  # Docker volume blocks is to only consider the single volume case.
  volume = {
    name = "${lookup(var.docker_volume, "name", "")}"

    docker_volume_configuration {
      autoprovision = "${lookup(var.docker_volume, "autoprovision", "")}"
      scope         = "${lookup(var.docker_volume, "scope", "")}"
      driver        = "${lookup(var.docker_volume, "driver", "")}"
    }
  }

  container_definitions = "[${join(",",data.template_file.container_definition.*.rendered)}]"
  network_mode          = "${var.awsvpc_enabled ? "awsvpc" : "bridge"}"

  # We need to ignore future container_definitions, and placement_constraints, as other tools take care of updating the task definition
  lifecycle {
    ignore_changes = ["container_definitions", "placement_constraints"]
  }

  requires_compatibilities = ["${var.launch_type}"]
}
