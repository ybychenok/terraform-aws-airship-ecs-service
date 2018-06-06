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
    lb_priority           = ""
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

variable "desired_capacity" {
  default = "2"
}

variable "autoscaling_enabled" {
  default = "0"
}

variable "desired_min_capacity" {
  default = "2"
}

variable "desired_max_capacity" {
  default = "2"
}

variable "autoscale_period_high" {
  default = "300"
}

variable "autoscale_period_low" {
  default = "180"
}

variable "autoscale_cpu_lowthreshold" {
  default = "5"
}

variable "autoscale_cpu_highthreshold" {
  default = "30"
}

variable "autoscale_cpu_low_evaluation_periods" {
  default = "1"
}

variable "autoscale_cpu_high_evaluation_periods" {
  default = "1"
}

variable "aws_zone_id" {
  default = ""
}

####

variable "name" {
  description = "The name of the project, must be unique ."
}

variable "container_port" {
  default     = "3000"
  description = "The name of the project, must be unique ."
}

variable "cpu" {
  default = "256"
}

variable "mem" {
  default = "512"
}

variable "deployment_maximum_percent" {
  default = "150"
}

variable "deployment_minimum_healthy_percent" {
  default = "50"
}

variable "launch_type" {
  default = "EC2"
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

variable "target_group_target_type" {
  default = "instance"
}

variable "direction" {
  type = "map"

  default = {
    up   = ["GreaterThanOrEqualToThreshold", "scale_out"]
    down = ["LessThanThreshold", "scale_in"]
  }
}

