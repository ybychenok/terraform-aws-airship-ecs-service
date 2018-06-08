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

  awsvpc_enabled = "${length(var.awsvpc_subnets) > 0 ? 1 : 0}"
}

module "iam" {
  source          = "./modules/iam/"
  name            = "${local.cluster_name}-${var.name}"
  create          = "${var.create}"
  region          = "${local.region}"
  kms_keys        = "${var.kms_keys}"
  ssm_paths       = "${var.ssm_paths}"
  s3_ro_paths     = "${var.s3_ro_paths}"
  s3_rw_paths     = "${var.s3_rw_paths}"
  fargate_enabled = "${local.fargate_enabled}"
}

module "alb_handling" {
  source                = "./modules/alb_handling/"
  name                  = "${var.name}"
  cluster_name          = "${local.cluster_name}"
  create                = "${var.create}"
  lb_arn                = "${lookup(var.load_balancing_properties,"lb_arn", "")}"
  lb_listener_arn       = "${lookup(var.load_balancing_properties,"lb_listener_arn", "")}"
  lb_listener_arn_https = "${lookup(var.load_balancing_properties,"lb_listener_arn_https", "")}"
  unhealthy_threshold   = "${lookup(var.load_balancing_properties,"lb_listener_arn_https", var.default_load_balancing_properties_unhealthy_threshold)}"
  create_route53_zone   = true
  custom_listen_host    = "${lookup(var.load_balancing_properties,"custom_listen_host", "")}"
  health_uri            = "${lookup(var.load_balancing_properties,"health_uri", var.default_load_balancing_properties_health_uri)}"
  target_type           = "${local.awsvpc_enabled ? "ip" : "instance"}"
  awsvpc_enabled        = "${local.awsvpc_enabled}"
}

###### CloudWatch Logs
resource "aws_cloudwatch_log_group" "app" {
  count             = "${var.create}"
  name              = "${local.cluster_name}/${var.name}"
  retention_in_days = 14
}

module "ecs_task_definition" {
  source                      = "./modules/ecs_task_definition/"
  name                        = "${local.cluster_name}-${var.name}"
  cluster_name            = "${local.cluster_name}"
  container_properties        = "${var.container_properties}"
  awsvpc_enabled              = "${local.awsvpc_enabled}"
  fargate_enabled             = "${local.fargate_enabled}"
  cloudwatch_loggroup_name    = "${aws_cloudwatch_log_group.app.name}"
  container_envvars           = "${var.container_envvars}"
  ecs_taskrole_arn            = "${module.iam.ecs_taskrole_arn}"
  ecs_task_execution_role_arn = "${module.iam.ecs_task_execution_role_arn}"
  launch_type                 = "${local.launch_type}"
  region                      = "${local.region}"
}

module "ecs_service" {
  source                  = "./modules/ecs_service/"
  name                    = "${local.cluster_name}-${var.name}"
  create                  = "${var.create}"
  cluster_id              = "${local.cluster_id}"
  ecs_task_definition_arn = "${module.ecs_task_definition.aws_ecs_task_definition_arn}"
  launch_type             = "${local.launch_type}"

  deployment_maximum_percent         = "${lookup(var.capacity_properties,"deployment_maximum_percent", var.default_capacity_properties_deployment_maximum_percent)}"
  deployment_minimum_healthy_percent = "${lookup(var.capacity_properties,"deployment_minimum_healthy_percent", var.default_capacity_properties_deployment_minimum_healthy_percent)}"
  awsvpc_subnets                     = "${var.awsvpc_subnets}"
  awsvpc_security_group_ids          = "${var.awsvpc_security_group_ids}"

  lb_create           = "${module.alb_handling.create}"
  lb_target_group_arn = "${module.alb_handling.lb_target_group_arn}"

  desired_capacity = "${lookup(var.capacity_properties,"desired_capacity", var.default_capacity_properties_desired_capacity)}"

  container_name = "${module.ecs_task_definition.container0_name}"
  container_port = "${module.ecs_task_definition.container0_port}"
}

module "ecs_autoscaling" {
  source = "./modules/ecs_autoscaling/"
  create = "${var.create} * length(var.scaling_properties) > 0 ? 1 : 0 }"

  cluster_name         = "${local.cluster_name}"
  ecs_service_name     = "${module.ecs_service.ecs_service_name}"
  desired_min_capacity = "${lookup(var.capacity_properties,"desired_min_capacity", var.default_capacity_properties_desired_min_capacity)}"
  desired_max_capacity = "${lookup(var.capacity_properties,"desired_max_capacity", var.default_capacity_properties_desired_max_capacity)}"
  scaling_properties   = "${var.scaling_properties}"
}
