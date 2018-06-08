variable "name" {}
variable "cluster_name" {}

variable "container_properties" {
  type = "list"
}

variable "awsvpc_enabled" {}
variable "fargate_enabled" {}
variable "cloudwatch_loggroup_name" {}

variable "container_envvars" {
  default = []
}

variable "ecs_taskrole_arn" {}
variable "ecs_task_execution_role_arn" {}
variable "region" {}
variable "launch_type" {}

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

locals {
  container0_name = "${lookup(var.container_properties[0], "name")}"
  container0_port = "${lookup(var.container_properties[0], "port")}"

  task_type_env = "${map("TASK_TYPE",lookup(var.container_properties[0], "task_type",""))}"
  ssm_available = "${map("SSM_AVAILABLE","true")}"
  base_env_vars = "${list(local.task_type_env,local.ssm_available)}"
}

data "template_file" "task_definition" {
  count = "${length(var.container_properties)}"

  template = "${file("${"${path.module}/task-definition.json"}")}"

  vars {
    image_url = "${lookup(var.container_properties[count.index], "image_url")}"
    task_type = "${lookup(var.container_properties[count.index], "task_type","")}"
    region    = "${var.region}"
    cpu       = "${lookup(var.container_properties[count.index], "cpu")}"
    mem       = "${lookup(var.container_properties[count.index], "mem")}"
    envvars   = "${jsonencode(concat(local.base_env_vars,var.container_envvars))}"

    portmappings_block = "${count.index == 0 ? data.template_file.portmapping.rendered : ""}"

    container_name   = "${lookup(var.container_properties[count.index], "name")}"
    discovery_name   = "${var.name}"
    hostname_block   = "${var.awsvpc_enabled == 0 ? "\"hostname\":\"${var.cluster_name}-${var.name}-${count.index}\",\n" :""}"
    log_group_region = "${var.region}"
    log_group_name   = "${var.cloudwatch_loggroup_name}"
    log_group_stream = "${lookup(var.container_properties[count.index], "name")}"
  }
}

resource "aws_ecs_task_definition" "app" {
  family        = "${var.name}"
  task_role_arn = "${var.ecs_taskrole_arn}"

  # Execution role ARN can be needed inside FARGATE
  execution_role_arn = "${var.ecs_task_execution_role_arn}"

  cpu    = "${var.fargate_enabled  ? lookup(var.container_properties[0], "cpu"): "" }"
  memory = "${var.fargate_enabled  ? lookup(var.container_properties[0], "mem"): "" }"

  container_definitions = "[${join(",",data.template_file.task_definition.*.rendered)}]"
  network_mode          = "${var.awsvpc_enabled == 1 ? "awsvpc" : "bridge"}"

  lifecycle {
    ignore_changes = ["container_definitions", "placement_constraints"]
  }

  requires_compatibilities = ["${var.launch_type}"]
}

output "container0_name" {
  value = "${local.container0_name}"
}

output "container0_port" {
  value = "${local.container0_port}"
}

output "aws_ecs_task_definition_arn" {
  value = "${aws_ecs_task_definition.app.arn}"
}
