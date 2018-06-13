locals {
  cluster_name = "web"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "test"
  cidr = "10.10.0.0/16"

  azs             = ["us-east-1d"]
  public_subnets  = ["10.10.11.0/24"]
  private_subnets = ["10.10.11.0/24"]

  enable_nat_gateway   = true
  enable_dns_hostnames = true
  enable_vpn_gateway   = false

  tags = {
    Terraform   = "true"
    Environment = "${terraform.workspace}"
  }
}

resource "aws_ecs_cluster" "this" {
  name = "${local.cluster_name}"

  lifecycle {
    create_before_destroy = true
  }
}

module "public_alb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "2.0.0"

  name        = "public_alb_sg"
  description = "Security Group for the public LB"

  vpc_id = "${module.vpc.vpc_id}"

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]

  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}

module "alb_shared_services_ext" {
  source                    = "terraform-aws-modules/alb/aws"
  load_balancer_name        = "shared-ext-alb"
  security_groups           = ["${module.public_alb_sg.this_security_group_id}"]
  load_balancer_is_internal = false
  log_bucket_name           = "${aws_s3_bucket.logs-bucket.id}"
  log_location_prefix       = ""
  subnets                   = ["${module.vpc.public_subnets}"]
  tags                      = "${map("Environment", "${terraform.workspace}")}"
  vpc_id                    = "${module.vpc.vpc_id}"
  https_listeners           = "${list(map("certificate_arn", "${var.aws_external_domain}", "port", 443))}"
  https_listeners_count     = "1"
  http_tcp_listeners        = "${list(map("port", "80", "protocol", "HTTP"))}"
  http_tcp_listeners_count  = "1"
  target_groups             = "${list(map("name", "default", "backend_protocol", "HTTP", "backend_port", "80"))}"
  target_groups_count       = "1"
}

# KMS Key used for ALL services i.e. to have access to shared keys residing in SSM
module "global_kms" {
  source = "github.com/blinkist/airship-tf-kms"
  name   = "global"
}

module "demo_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "2.0.0"

  name        = "demo-service-sg"
  description = "Security Group for the ECS Instance SG"

  vpc_id = "${module.vpc.vpc_id}"

  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  ingress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      description              = "allow ports to public ALB"
      source_security_group_id = "${module.public_alb_sg.this_security_group_id}"
    },
  ]
}

# KMS Key used for demo_kms
module "demo_kms" {
  source = "github.com/blinkist/airship-tf-kms"
  name   = "demo"
}

module "demo_web" {
  source = "github.com/blinkist/airship-tf-ecs-service/"

  name   = "demo-web"
  create = true

  ecs_cluster_name = "${local.cluster_name}"
  fargate_enabled  = true

  # AWSVPC Block, with awsvpc_subnets defined the network_mode for the ECS task definition will be awsvpc, defaults to bridge 
  awsvpc_enabled            = true
  awsvpc_subnets            = ["${module.vpc.private_subnets}"]
  awsvpc_security_group_ids = ["${module.demo_sg.this_security_group_id}"]

  container_properties = [
    {
      image_url  = "nginx:latest"
      name       = "nginx"
      port       = "80"
      health_uri = "/ping"
      mem        = "512"
      cpu        = "256"
    },
  ]

  # Initial ENV Variables for the ECS Task definition
  container_envvars {
    SSM_ENABLED = "true"
    TASK_TYPE   = "web"
  }

  # capacity_properties defines the size in task for the ECS Service.
  # Without scaling enabled, desired_capacity is the only necessary property
  # With scaling enabled, desired_min_capacity and desired_max_capacity define the lower and upper boundary in task size
  capacity_properties {
    desired_capacity     = "2"
    desired_min_capacity = "2"
    desired_max_capacity = "5"
  }

  # https://docs.aws.amazon.com/autoscaling/application/userguide/what-is-application-auto-scaling.html
  scaling_properties = [
    {
      type               = "CPUUtilization"
      direction          = "up"
      evaluation_periods = 2
      observation_period = "300"
      statistic          = "Average"
      threshold          = "89"
      cooldown           = "900"
      adjustment_type    = "ChangeInCapacity"
      scaling_adjustment = "1"
    },
    {
      type               = "CPUUtilization"
      direction          = "down"
      evaluation_periods = 4
      observation_period = "300"
      statistic          = "Average"
      threshold          = "10"
      cooldown           = "300"
      adjustment_type    = "ChangeInCapacity"
      scaling_adjustment = "-1"
    },
  ]

  # The KMS Keys which can be used for kms:decrypt
  kms_keys = ["${module.global_kms.aws_kms_key_arn}", "${module.demo_kms.aws_kms_key_arn}"]

  # The SSM paths which are allowed to do kms:GetParameter and ssm:GetParametersByPath for
  # Using the names of the kms keys, as they correlate
  ssm_paths = ["${module.global_kms.name}", "${module.demo_kms.name}"]
}
