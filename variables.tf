variable "ecs_properties" {
  type = "map"

  default = {
    ecs_cluster_name    = ""
    service_launch_type = "EC2"
    memory              = "512"
    cpu                 = "256"
  }
}

variable "load_balancing_properties" {
  type = "map"

  default = {
    alb_attached          = true
    lb_listener_arn       = ""
    lb_listener_arn_https = ""
    lb_vpc_id             = ""
    route53_zone_id       = ""
    health_uri            = "/ping"
    unhealthy_threshold   = "3"
  }
}

variable "capacity_properties" {
  type = "map"

  default = {
    desired_capacity     = "2"
    desired_min_capacity = "2"
    desired_max_capacity = "5"
    deployment_maximum_percent = "200"
    deployment_minimum_healthy_percent = "0"
  }
}

variable "scaling_properties" {
  default = []
}

variable "container_properties" {
  type = "list"
}

variable "task_type" {
  description = "The type of the task, either WEB or WORKER"
  default     = "web"
}

####

variable "name" {
  description = "The name of the project, must be unique ."
}

variable "kms_keys" {
  default = []
}

variable "ssm_paths" {
  default = []
}

variable "awsvpc_subnets" {
  default = []
}

variable "awsvpc_security_group_ids" {
  default = []
}

variable "awsvpc_enabled" {
  default = false
}

variable "s3_ro_paths" {
  default = []
}

variable "s3_rw_paths" {
  default = []
}

variable "direction" {
  type = "map"

  default = {
    up   = ["GreaterThanOrEqualToThreshold", "scale_out"]
    down = ["LessThanThreshold", "scale_in"]
  }
}

