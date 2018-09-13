# name of the ecs_service
variable "name" {}

# create
variable "create" {
  default = true
}

# cluster name
variable "cluster_name" {}

# List of maps with container properties
variable "container_properties" {
  type = "list"
}

# is awsvpc enabled ?
variable "awsvpc_enabled" {
  default = false
}

# is fargate enabled ?
variable "fargate_enabled" {
  default = false
}

# cloudwatch_loggroup_name sets the cloudwatch loggroup name
variable "cloudwatch_loggroup_name" {
  default = ""
}

#  extra set of environment variables for the ecs task
variable "container_envvars" {
  default = {}
}

# ecs_taskrole_arn sets the arn of the ECS Task role
variable "ecs_taskrole_arn" {}

# ecs_task_execution_role_arn sets the execution role arn, needed for FARGATE
variable "ecs_task_execution_role_arn" {}

# AWS Region
variable "region" {}

# launch_type sets the launch_type, either EC2 or FARGATE
variable "launch_type" {}

# list of docker volumes to add to the task
variable "docker_volumes" {
  type    = "list"
  default = []

  # {
  #    name = "bla",
  #    scope == "shared",
  #    autoprovision = true,
  #    driver = "foo"
  # }
  #
  /* NOT supported, as these are maps
     driver_opts = N/A
     labels = N/A
  */
}

# list of host paths to add to the task
variable "host_path_volumes" {
  type    = "list"
  default = []

  # {
  #   name = "service-storage",
  #   host_path = "/foo"
  # },
}

# list of mount points to add to every container in the task
variable "mountpoints" {
  type    = "list"
  default = []

  # {
  #   source_volume = "service-storage"
  #   container_path = "/foo"
  #   read_only = "false"
  # },
}
