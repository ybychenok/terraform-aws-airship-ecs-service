output "container0_name" {
  value = "${local.container0_name}"
}

output "container0_port" {
  value = "${local.container0_port}"
}

output "aws_ecs_task_definition_arn" {
  value = "${element(concat(aws_ecs_task_definition.app.*.arn, list("")), 0)}"
}
