# ecs_service_name sets the service name
variable "ecs_service_name" {}

# create sets if resources are created
variable "create" {}

# container_name sets the name of the container where we lookup the container_image
variable "container_name" {}

# ecs_cluster_id sets the cluster id
variable "ecs_cluster_id" {}

# lambda_lookup_role_arn sets the role arn of the lookup_lambda
variable "lambda_lookup_role_arn" {}

# lookup_type sets the type of lookup, either 
# * lambda - works during bootstrap and after bootstrap
# * datasource - uses terraform datasources ( aws_ecs_service ) which won't work during bootstrap
variable "lookup_type" {
  default = "lambda"
}

# tags
variable "tags" {
  default = {}
}
