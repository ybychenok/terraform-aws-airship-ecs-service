# To pretify the  use of this module externally we use maps. Downside of map-usage is that default variables are lost when only a part
# of the map is being defined. This is mitigated by using an extra set of default_* variables 

variable "create" {
  default = true
}

# The ECS Cluster name
variable "ecs_cluster_name" {}

# With fargate_enabled the launchtype of the service will be FARGATE, otherwise EC2 ( default is false)
variable "fargate_enabled" {
  default = false
}

# With awsvpc_enabled the network_mode for the ECS task definition will be awsvpc, defaults to bridge 
variable "awsvpc_enabled" {
  default = false
}

# scheduling_strategy defaults to REPLICA
variable "scheduling_strategy" {
  default = "REPLICA"
}

# Spread tasks over ECS Cluster based on AZ, Instance-id, memory
variable "with_placement_strategy" {
  default = false
}

# Extra hosts the ALB needs to make listener_rules for to the ECS target group
variable "custom_listen_hosts" {
  default = []
  type    = "list"
}

# load_balancing_enabled defines if we are using a load balancer for our ecs service
variable "load_balancing_enabled" {
  default = false
}

## load_balancing_properties map defines the map for services hooked to a load balancer
variable "load_balancing_properties" {
  type = "map"

  default = {
    #   # DEFAULT VALUES are derived from default_load_balancing_properties_*  #  # lb_listener_arn is the ALB listener arn for HTTP  # lb_listener_arn = ""  # lb_listener_arn_https is the ALB listener arn for HTTPS  # lb_listener_arn_https = ""  # lb_vpc_id is the vpc_id for the target_group to reside in  # lb_vpc_id = ""  # route53_zone_id is the zone to add a subdomain to  # route53_zone_id = ""  # health_uri is the health uri to be checked by the ALB   # health_uri = "/ping"  # unhealthy_threshold is the health uri to be checked by the ALB   # unhealthy_threshold = "3"  # Do we create listener rules for https  # https_enabled = true  # Do we want to create a subdomain for the service inside the Route53 zone  # create_route53_record = true
  }
}

variable "default_load_balancing_properties_lb_listener_arn" {
  default = ""
}

variable "default_load_balancing_properties_lb_listener_arn_https" {
  default = ""
}

variable "default_load_balancing_properties_lb_vpc_id" {
  default = ""
}

variable "default_load_balancing_properties_route53_zone_id" {
  default = ""
}

variable "default_load_balancing_properties_health_uri" {
  default = "/ping"
}

variable "default_load_balancing_properties_unhealthy_threshold" {
  default = "3"
}

variable "default_load_balancing_properties_deregistration_delay" {
  default = 300
}

variable "default_load_balancing_properties_https_enabled" {
  default = true
}

variable "default_load_balancing_properties_route53_a_record_identifier" {
  default = "identifier"
}

variable "default_load_balancing_properties_create_route53_record" {
  default = true
}

# By default we create a CNAME to the ALB, the moment terraform can handle CNAME to IN A ALIAS record changes
# Route53 IN A Alias will be the default.
# https://github.com/terraform-providers/terraform-provider-aws/issues/5280
variable "default_load_balancing_properties_route53_record_type" {
  default = "CNAME"
}

## capacity_properties map defines the capacity properties of the service
variable "capacity_properties" {
  type = "map"

  default = {
    #   # DEFAULT VALUES are derived from default_capacity_properties_*  #  # desired_capacity is the desired amount of tasks for a service, when autoscaling is used desired_capacity is only used initially  # after that autoscaling determins the amount of tasks   # desired_capacity = "2"  # desired_min_capacity is used when autoscaling is used, it sets the minimum of tasks to be available for this service  # desired_min_capacity = "2"  # desired_max_capacity is used when autoscaling is used, it sets the maximum of tasks to be available for this service  # desired_max_capacity = "5"  # deployment_maximum_percent sets the maximum deployment size of the current capacity, 200% means double the amount of current tasks  # will be active in case a deployment is happening  # deployment_maximum_percent = "200"  # deployment_minimum_healthy_percent sets the minimum deployment size of the current capacity, 0% means no tasks need to be running at the moment of  # a deployment switch  # deployment_minimum_healthy_percent = "0"
  }
}

variable "default_capacity_properties_desired_capacity" {
  default = "2"
}

variable "default_capacity_properties_desired_min_capacity" {
  default = "2"
}

variable "default_capacity_properties_desired_max_capacity" {
  default = "2"
}

variable "default_capacity_properties_deployment_maximum_percent" {
  default = "200"
}

variable "default_capacity_properties_deployment_minimum_healthy_percent" {
  default = "0"
}

# container_properties is a list which can contain multiple maps with information about the containers the task definition are running.
# as AWS Fargate and docker are not supporting linking anymore this feature is not supported. Running multiple containers in one 
# Task however is possible. For Networking the properties of the first container are used.
# [{
#     # image_url defines the docker image url
#     image_url  = "nginx:latest"
#
#     # name defines the name of the container, this is used for the AWS Logstream, and the targetgroup registration
#     name       = "nginx"
#   
#     # The port of the application
#     port       = "80"
#
#     # mem_reservation defines the soft limit for the container, defaults to null
#     mem_reservation  = "null"
#
#     # memory defines the needed memory for the container
#     mem        = "512"
#
#     # cpu defines the needed cpu for the container
#     cpu        = "256"
#  }]

variable "container_properties" {
  type = "list"
}

variable "default_container_properties_image_url" {
  default = ""
}

variable "default_container_properties_name" {
  default = "app"
}

variable "default_container_properties_port" {
  default = ""
}

variable "default_container_properties_mem_reservation" {
  default = ""
}

variable "default_container_properties_mem" {
  default = "512"
}

variable "default_container_properties_cpu" {
  default = "256"
}

# Scaling properties holds a map of multiple maps defining scaling policies and alarms
#
#
#  [{
#     # type is the metric the metric being used for the service
#     type               = "CPUUtilization"
#     
#     # direction defines the direction of the scaling, up means more tasks, down is less tasks
#     direction          = "up"
#
#     # evaluation_periods how many observation points are needed for a scaling decision
#     evaluation_periods = "2"
#
#     
#     # observation_period is the number of seconds one statistic is measured
#     observation_period = "300"
#
#     # statistic defines the type of statistic for measuring SampleCount, Average, Sum, Minimum, Maximum
#     statistic          = "Average"
#
#     # threshold defines the value which is needed to surpass, given the direction
#     threshold          = "89"
#
#     # Cooldown defines the amount of seconds in which another scaling is disabled after a succesful scaling action
#     cooldown           = "900"
#
#     # Adjustment_type defines the type of adjustment, can either be absolute or relative : ChangeInCapacity, ExactCapacity, and PercentChangeInCapacity.
#     adjustment_type    = "ChangeInCapacity"
# 
#     # scaling_adjustment defines the amount to scale, can be a postive or negative number or percentage
#     scaling_adjustment = "1"
#   },]

variable "scaling_properties" {
  default = []
}

# container_envvars defines extra container env vars, list of maps
# { key = val,key2= val2}

variable "container_envvars" {
  default = {}
}

####

variable "name" {
  description = "The name of the project, must be unique ."
}

# List of KMS keys the task has access to
variable "kms_keys" {
  default = []
}

# List of SSM Paths the task has access to
variable "ssm_paths" {
  default = []
}

# AWSVPC ( FARGATE ) need subnets to reside in
variable "awsvpc_subnets" {
  default = []
}

# AWSVPC ( FARGATE ) need awsvpc_security_group_ids attached to the task
variable "awsvpc_security_group_ids" {
  default = []
}

# S3 Read-only paths the Task has access to
variable "s3_ro_paths" {
  default = []
}

# S3 Read-write paths the Task has access to
variable "s3_rw_paths" {
  default = []
}
