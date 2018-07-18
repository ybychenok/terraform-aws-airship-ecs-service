locals {
  cluster_name = "web"
  workspace    = "dev"
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

module "private_alb_sg" {
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

module "ecs_instance_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "ecs_instance_sg"
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
      from_port                = 32768
      to_port                  = 65535
      protocol                 = "tcp"
      description              = "allow ports to internal ALB"
      source_security_group_id = "${module.private_alb_sg.this_security_group_id}"
    },
    {
      from_port                = 32768
      to_port                  = 65535
      protocol                 = "tcp"
      description              = "allow ports to public ALB"
      source_security_group_id = "${module.public_alb_sg.this_security_group_id}"
    },
  ]
}

# Seperate ECS cluster for web services
module "ecs_web" {
  source = "github.com/blinkist/airship-tf-ecs-cluster/"

  name        = "${terraform.workspace}-web"
  environment = "${terraform.workspace}"

  vpc_id     = "${module.vpc.vpc_id}"
  subnet_ids = ["${module.vpc.private_subnets}"]

  cluster_properties {
    create            = true
    ec2_key_name      = "${aws_key_pair.main.key_name}"
    ec2_instance_type = "t2.small"
    ec2_asg_min       = "1"
    ec2_asg_max       = "1"
    ec2_disk_size     = "40"
    ec2_disk_type     = "gp2"
  }

  ecs_instance_scaling_create = false

  vpc_security_group_ids = ["${module.ecs_instance_sg.this_security_group_id}", "${module.admin_sg.this_security_group_id}"]

  tags = {
    Environment = "${terraform.workspace}"
  }
}

# Seperate ECS cluster for workers
module "ecs_worker" {
  source = "github.com/blinkist/airship-tf-ecs-cluster/"

  name        = "${local.workspace}-worker"
  environment = "${local.workspace}"

  vpc_id     = "${module.vpc.vpc_id}"
  subnet_ids = ["${module.vpc.private_subnets}"]

  cluster_properties {
    create            = true
    ec2_key_name      = "${aws_key_pair.main.key_name}"
    ec2_instance_type = "t2.small"
    ec2_asg_min       = "1"
    ec2_asg_max       = "1"
    ec2_disk_size     = "40"
    ec2_disk_type     = "gp2"
  }

  ecs_instance_scaling_create = false

  vpc_security_group_ids = ["${module.ecs_instance_sg.this_security_group_id}"]

  tags = {
    Environment = "${local.workspace}"
  }
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

  # We put WEB services on the web ECS Cluster. This way rogue workers processes cannot effect the web performance
  ecs_cluster_name = "${module.ecs_web.ecs_cluster_name}"

  # load_balancing_properties take care of binding the service to an ( Application Load Balancer) ALB
  load_balancing_properties {
    lb_arn                = "${module.alb_shared_services_ext.load_balancer_id}"
    lb_listener_arn_https = "${element(module.alb_shared_services_ext.https_listener_arns,0)}"
    lb_listener_arn       = "${element(module.alb_shared_services_ext.http_tcp_listener_arns,0)}"
    lb_vpc_id             = "${module.vpc.vpc_id}"
    route53_zone_id       = "${aws_route53_zone.shared_ext_services_domain.zone_id}"
    create_route53_record = true
    unhealthy_threshold   = "3"
  }

  custom_listen_hosts = ["www.example.com"]

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

  # With no scaling and capacity-properties defined we get a non-scaling capacity of 2 tasks

  # The KMS Keys which can be used for kms:decrypt
  kms_keys = ["${module.global_kms.aws_kms_key_arn}", "${module.demo_kms.aws_kms_key_arn}"]
  # The SSM paths which are allowed to do kms:GetParameter and ssm:GetParametersByPath for
  # Using the names of the kms keys, as they correlate
  ssm_paths = ["${module.global_kms.name}", "${module.demo_kms.name}"]
}

module "demo_worker" {
  source = "github.com/blinkist/airship-tf-ecs-service/"

  name = "demo-worker"

  # We put worker-services on the web ECS Cluster. This way rogue workers processes cannot effect the web performance
  ecs_cluster_name = "${module.ecs_web.ecs_cluster_name}"

  # With no load_balancing_properties this docker is
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
    TASK_TYPE   = "worker"
  }

  # With no scaling and capacity-properties defined we get a non-scaling capacity of 2 tasks

  # The KMS Keys which can be used for kms:decrypt
  kms_keys = ["${module.global_kms.aws_kms_key_arn}", "${module.demo_kms.aws_kms_key_arn}"]
  # The SSM paths which are allowed to do kms:GetParameter and ssm:GetParametersByPath for
  # Using the names of the kms keys, as they correlate
  ssm_paths = ["${module.global_kms.name}", "${module.demo_kms.name}"]
}
