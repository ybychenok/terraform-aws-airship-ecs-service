# The arn of the task definition
output "aws_ecs_task_definition_arn" {
  value = "${element(concat(aws_ecs_task_definition.app.*.arn, aws_ecs_task_definition.app_with_docker_volume.*.arn, list("")), 0)}"
}
