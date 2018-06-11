data "aws_region" "current" {}

data "aws_ecs_cluster" "this" {
  cluster_name = "${local.cluster_name}"
}

locals {
  cluster_id   = "${data.aws_ecs_cluster.this.arn}"
  cluster_name = "${lookup(var.ecs_properties,"ecs_cluster_name")}"
  region       = "${data.aws_region.current.name}"

  fargate_enabled = "${lookup(var.ecs_properties,"service_launch_type", "EC2") == "FARGATE" ? true : false }"
  launch_type     = "${local.fargate_enabled ? "FARGATE" : "EC2" }"

  awsvpc_enabled = "${length(var.awsvpc_subnets) > 0 ? true : false }"
}

#
# The iam sub-module creates the IAM resources needed for the ECS Service. 
#
module "iam" {
  source = "./modules/iam/"

  # Name
  name = "${local.cluster_name}-${var.name}"

  # Create defines if any resources need to be created inside the module
  create = "${var.create}"

  # Region is used multiple times inside this module, we pass this through so that we don't need multiple datasources
  region = "${local.region}"

  # kms_keys define which KMS keys this ecs_service can access.
  kms_keys = "${var.kms_keys}"

  # ssm_paths define which SSM paths the ecs_service can access
  ssm_paths = "${var.ssm_paths}"

  # s3_ro_paths define which paths on S3 can be accessed from the ecs service in read-only fashion. 
  s3_ro_paths = "${var.s3_ro_paths}"

  # s3_ro_paths define which paths on S3 can be accessed from the ecs service in read-write fashion. 
  s3_rw_paths = "${var.s3_rw_paths}"

  # In case Fargate is enabled an extra role needs to be added
  fargate_enabled = "${local.fargate_enabled}"
}

#
# This sub-module creates everything regarding the connection of an ecs service to an Application Load Balancer
# 
module "alb_handling" {
  source = "./modules/alb_handling/"

  name         = "${var.name}"
  cluster_name = "${local.cluster_name}"

  # Create defines if we need to create resources inside this module
  create = "${var.create}"

  # lb_vpc_id sets the VPC ID of where the LB resides
  lb_vpc_id = "${lookup(var.load_balancing_properties,"lb_vpc_id", "")}"

  # lb_arn defines the arn of the ALB
  lb_arn = "${lookup(var.load_balancing_properties,"lb_arn", "")}"

  # lb_listener_arn is the arn of the listener ( HTTP )
  lb_listener_arn = "${lookup(var.load_balancing_properties,"lb_listener_arn", "")}"

  # lb_listener_arn is the arn of the listener ( HTTPS )
  lb_listener_arn_https = "${lookup(var.load_balancing_properties,"lb_listener_arn_https", "")}"

  # unhealthy_threshold defines the threashold for the target_group after which a service is seen as unhealthy.
  unhealthy_threshold = "${lookup(var.load_balancing_properties,"unhealthy_threshold", var.default_load_balancing_properties_unhealthy_threshold)}"

  # create_route53_zone sets if this module creates a Route53 zone.
  https_enabled = "${lookup(var.load_balancing_properties,"unhealthy_threshold", var.default_load_balancing_properties_https_enabled)}"

  # create_route53_zone sets if this module creates a Route53 zone.
  create_route53_record = true

  # Sets the zone in which the sub-domain will be added for this service
  route53_zone_id = "${lookup(var.load_balancing_properties,"route53_zone_id", "")}"

  # Sets name for the sub-domain, we default to *name
  route53_name = "${var.name}"

  # the custom_listen_host will be added as a host route rule as aws_lb_listener_rule to the given service e.g. www.domain.com -> Service
  custom_listen_host = "${lookup(var.load_balancing_properties,"custom_listen_host", "")}"

  # health_uri defines which health-check uri the target group needs to check on for health_check
  health_uri = "${lookup(var.load_balancing_properties,"health_uri", var.default_load_balancing_properties_health_uri)}"

  # target_type is the alb_target_group target, in case of EC2 it's instance, in case of FARGATE it's IP
  target_type = "${local.awsvpc_enabled ? "ip" : "instance"}"
}


####### CloudWatch Logs
#resource "aws_cloudwatch_log_group" "app" {
#  count             = "${var.create}"
#  name              = "${local.cluster_name}/${var.name}"
#  retention_in_days = 14
#}
#
##
## This sub-module creates the ECS Task definition
## 
#module "ecs_task_definition" {
#  source = "./modules/ecs_task_definition/"
#
#  # The name of the task_definition ( generally, a combination of the cluster name and the service name.)
#  name         = "${local.cluster_name}-${var.name}"
#  cluster_name = "${local.cluster_name}"
#
#  # container_properties defines a list of maps of container_properties
#  container_properties = "${var.container_properties}"
#
#  # awsvpc_enabled sets if the ecs task definition is awsvpc 
#  awsvpc_enabled = "${local.awsvpc_enabled}"
#
#  # fargate_enabled sets if the ecs task definition has launch_type FARGATE
#  fargate_enabled = "${local.fargate_enabled}"
#
#  # cloudwatch_loggroup_name sets the loggroup name of the cloudwatch loggroup made for this service.
#  cloudwatch_loggroup_name = "${aws_cloudwatch_log_group.app.name}"
#
#  # container_envvars defines a list of maps filled with key-val pairs of environment variables needed for the ecs task definition.
#  container_envvars = "${var.container_envvars}"
#
#  # ecs_taskrole_arn sets the IAM role of the task.
#  ecs_taskrole_arn = "${module.iam.ecs_taskrole_arn}"
#
#  # ecs_task_execution_role_arn sets the task-execution role needed for FARGATE. This role is also empty in case of EC2
#  ecs_task_execution_role_arn = "${module.iam.ecs_task_execution_role_arn}"
#
#  # Launch type, either EC2 or FARGATE
#  launch_type = "${local.launch_type}"
#
#  # region, needed for Logging.. 
#  region = "${local.region}"
#}
#
##
## This sub-module creates the ECS Service
## 
#module "ecs_service" {
#  source = "./modules/ecs_service/"
#  name   = "${local.cluster_name}-${var.name}"
#
#  # create defines if resources are being created inside this module
#  create = "${var.create}"
#
#  cluster_id = "${local.cluster_id}"
#
#  # ecs_task_definition_arn is the arn of the task definition, created by the ecs_task_definition module 
#  ecs_task_definition_arn = "${module.ecs_task_definition.aws_ecs_task_definition_arn}"
#
#  # launch_type either EC2 or FARGATE
#  launch_type = "${local.launch_type}"
#
#  # deployment_maximum_percent sets the maximum size of the deployment in % of the normal size.
#  deployment_maximum_percent = "${lookup(var.capacity_properties,"deployment_maximum_percent", var.default_capacity_properties_deployment_maximum_percent)}"
#
#  # deployment_minimum_healthy_percent sets the minimum % in capacity at depployment
#  deployment_minimum_healthy_percent = "${lookup(var.capacity_properties,"deployment_minimum_healthy_percent", var.default_capacity_properties_deployment_minimum_healthy_percent)}"
#
#  # awsvpc_subnets defines the subnets for an awsvpc ecs module
#  awsvpc_subnets = "${var.awsvpc_subnets}"
#
#  # awsvpc_security_group_ids defines the vpc_security_group_ids for an awsvpc module
#  awsvpc_security_group_ids = "${var.awsvpc_security_group_ids}"
#
#  # lb_create sets if the ECS Service will be LB connected
#  alb_connected = "${module.alb_handling.target_group_created}"
#
#  # lb_target_group_arn sets the arn of the target_group the service needs to connect to
#  lb_target_group_arn = "${module.alb_handling.lb_target_group_arn}"
#
#  # desired_capacity sets the initial capacity in task of the ECS Service
#  desired_capacity = "${lookup(var.capacity_properties,"desired_capacity", var.default_capacity_properties_desired_capacity)}"
#
#  # container_name sets the name of the container, this is used for the load balancer section inside the ecs_service to connect to a container_name defined inside the 
#  # task definition, container_port sets the port for the same container.
#  container_name = "${module.ecs_task_definition.container0_name}"
#
#  container_port = "${module.ecs_task_definition.container0_port}"
#}
#
##
## This modules sets the scaling properties of the ECS Service
##
#module "ecs_autoscaling" {
#  source = "./modules/ecs_autoscaling/"
#
#  # create defines if resources inside this module are being created.
#  create = "${(var.create ? 1 : 0 ) * (length(var.scaling_properties) > 0 ? 1 : 0 )}"
#
#  cluster_name = "${local.cluster_name}"
#
#  # ecs_service_name is derived from the actual ecs_service, this to force dependency at creation.
#  ecs_service_name = "${module.ecs_service.ecs_service_name}"
#
#  # desired_min_capacity, in case of autoscaling, desired_min_capacity sets the minimum size in tasks
#  desired_min_capacity = "${lookup(var.capacity_properties,"desired_min_capacity", var.default_capacity_properties_desired_min_capacity)}"
#
#  # desired_max_capaity, in case of autoscaling, desired_max_capacity sets the maximum size in tasks
#  desired_max_capacity = "${lookup(var.capacity_properties,"desired_max_capacity", var.default_capacity_properties_desired_max_capacity)}"
#
#  # scaling_properties holds a list of maps with the scaling properties defined.
#  scaling_properties = "${var.scaling_properties}"
#}

