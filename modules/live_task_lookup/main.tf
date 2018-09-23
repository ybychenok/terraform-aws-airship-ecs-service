variable "ecs_service_name" {}
variable "container_name" {}
variable "create" {}
variable "ecs_cluster_id" {}

data "aws_ecs_service" "lookup" {
  count        = "${var.create ? 1 : 0 }"
  service_name = "${var.ecs_service_name}"
  cluster_arn  = "${var.ecs_cluster_id}"
}

data "aws_ecs_task_definition" "lookup" {
  count           = "${var.create ? 1 : 0 }"
  task_definition = "${data.aws_ecs_service.lookup.task_definition}"
}

data "aws_ecs_container_definition" "lookup" {
  count           = "${var.create ? 1 : 0 }"
  task_definition = "${data.aws_ecs_service.lookup.task_definition}"
  container_name  = "${var.container_name}"
}

output "image" {
  value = "${element(concat(data.aws_ecs_container_definition.lookup.*.image, list("")), 0)}"
}

output "cpu" {
  value = "${element(concat(data.aws_ecs_container_definition.lookup.*.cpu, list("")), 0)}"
}

output "memory" {
  value = "${element(concat(data.aws_ecs_container_definition.lookup.*.memory, list("")), 0)}"
}

output "memory_reservation" {
  value = "${element(concat(data.aws_ecs_container_definition.lookup.*.memory_reservation, list("")), 0)}"
}

locals {
  environment_coalesce = "${coalescelist(data.aws_ecs_container_definition.lookup.*.environment, list(map()))}"
}

output "environment_json" {
  value = "${jsonencode(local.environment_coalesce[0])}"
}

output "revision" {
  value = "${element(concat(data.aws_ecs_task_definition.lookup.*.revision, list("")), 0)}"
}
