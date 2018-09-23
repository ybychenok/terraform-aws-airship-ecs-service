variable "ecs_container_name" {}

variable "allow_terraform_deploy" {
  default = "true"
}

# Reflecting the current state

variable "aws_ecs_task_definition_family" {}
variable "aws_ecs_task_definition_revision" {}

# Reflecting the live state independent of the Terraform state

variable "live_aws_ecs_task_definition_revision" {}
variable "live_aws_ecs_task_definition_image" {}
variable "live_aws_ecs_task_definition_cpu" {}
variable "live_aws_ecs_task_definition_memory" {}
variable "live_aws_ecs_task_definition_memory_reservation" {}
variable "live_aws_ecs_task_definition_environment_json" {}
