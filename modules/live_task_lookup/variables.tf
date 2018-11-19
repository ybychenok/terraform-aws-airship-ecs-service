#TODO
variable "ecs_service_name" {}

variable "container_name" {}
variable "create" {}
variable "ecs_cluster_id" {}
variable "lambda_lookup_role_arn" {}

variable "lookup_type" {
  default = "lambda"
}

variable "tags" {
  default = {}
}
