# The name of the first container
output "container0_name" {
  value = "${local.container0_name}"
}

# The port of the first container
output "container0_port" {
  value = "${local.container0_port}"
}

# The arn of the task definition
output "aws_ecs_task_definition_arn" {
  value = "${element(concat(aws_ecs_task_definition.app.*.arn, aws_ecs_task_definition.app_with_docker_volume.*.arn), 0)}"
}
