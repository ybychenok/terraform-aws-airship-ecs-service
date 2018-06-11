# ecs_task_execution_role_arn outputs the Role-Arn for the ECS Task Execution role.
output "ecs_task_execution_role_arn" {
  value = "${element(concat(aws_iam_role.ecs_task_execution_role.*.arn, list("")), 0)}"
}

# ecs_taskrole_arn outputs the Role-Arn of the ECS Task
output "ecs_taskrole_arn" {
  value = "${element(concat(aws_iam_role.ecs_tasks_role.*.arn, list("")), 0)}"
}
