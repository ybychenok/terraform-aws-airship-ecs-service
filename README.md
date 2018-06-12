# AWS ECS Service Terraform Module

Hi there ! This module is Work in Progress! Do not source from github. 
Do you see any issues? Create an issue!

Thanks,

Maarten


## Features
* [x] Can be conditionally created
* [x] Creates all necessary IAM Roles for running an ECS Service
* [x] Integrated IAM Permissions for KMS
* [x] Integrated IAM Permissions for SSM
* [x] Integrated IAM Permissions for S3
* [x] Creation of an ECS service, with/without AWSVPC, with/without FARGATE
* [x] Creation of ECS Task definition for use with/without AWSVPC, with/without FARGATE 
* [x] Integrated Cloudwatch Logging
* [x] Integrated Service Scaling
* [x] Handling of Creating listener rules to one ALB
* [x] Exports role arn for adding permissions 
* [ ] Terratest..
* [ ] Service discovery
* [ ] SSL SNI Adding for custom hostnames

## Will not feature
* [ ] mounting EFS mounts within ECS Task, in theory possible, but stateful workloads should not be on ECS anyway

## known issues
* [ ] At destroy, aws_appautoscaling_policy.policy.1: Failed to delete scaling policy: ObjectNotFoundException, 


## Simple ECS Service on Fargate with ALB Attached

```hcl

module "demo_web" {
  source = "github.com/blinkist/airship-tf-ecs-service/"

  name   = "demo-web"

  ecs_cluster_name = "${local.cluster_name}"
  fargate_enabled = true

  # AWSVPC Block, with awsvpc_subnets defined the network_mode for the ECS task definition will be awsvpc, defaults to bridge 
  awsvpc_subnets            = ["${module.vpc.private_subnets}"]
  awsvpc_security_group_ids = ["${module.demo_sg.this_security_group_id}"]

  # load_balancing_properties takes care of binding the service to an ( Application Load Balancer) ALB
  # when left-out the service, will not be attached to a load-balancer 
  load_balancing_properties {

    # The ARN of the ALB, when left-out the service, will not be attached to a load-balance
    lb_arn                = "${module.alb_shared_services_ext.load_balancer_id}"
    # https listener ARN
    lb_listener_arn_https = "${element(module.alb_shared_services_ext.https_listener_arns,0)}"

    # http listener ARN
    lb_listener_arn       = "${element(module.alb_shared_services_ext.http_tcp_listener_arns,0)}"

    # The VPC_ID the target_group is being created in
    lb_vpc_id             = "${module.vpc.vpc_id}"

    # The route53 zone for which we create a subdomain
    route53_zone_id       = "${aws_route53_zone.shared_ext_services_domain.zone_id}"

    # Do we actually want to create the subdomain, default to true
    # create_route53_record = true

    # After which threshold in health check is the task marked as unhealthy, defaults to 3
    # unhealthy_threshold   = "3"

    # custom_listen_host defines an extra listener rule for this specific host-header, defaults to empty
    # custom_listen_host    = "www.example.com"

    # health_uri defines which health-check uri the target group needs to check on for health_check, defaults to /ping
    # health_uri = "/ping"
  }

  container_properties = [
    {
      image_url  = "nginx:latest"
      name       = "nginx"
      port       = "80"
      mem        = "512"
      cpu        = "256"
    },
  ]

  # Initial ENV Variables for the ECS Task definition
  container_envvars  {
       KEVIN = "bacon"
       ECS = "OK"
       TASK_TYPE = "web" 
  } 

  # capacity_properties defines the size in task for the ECS Service.
  # Without scaling enabled, desired_capacity is the only necessary property, defaults to 2
  # With scaling enabled, desired_min_capacity and desired_max_capacity define the lower and upper boundary in task size
  capacity_properties {
    #desired_capacity     = "2"
    #desired_min_capacity = "2"
    #desired_max_capacity = "2"
  }

  # https://docs.aws.amazon.com/autoscaling/application/userguide/what-is-application-auto-scaling.html
  scaling_properties = [
    {
      type               = "CPUUtilization"
      direction          = "up"
      evaluation_periods = "2"
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
      evaluation_periods = "4"
      observation_period = "300"
      statistic          = "Average"
      threshold          = "10"
      cooldown           = "300"
      adjustment_type    = "ChangeInCapacity"
      scaling_adjustment = "-1"
    },
  ]

  # The KMS Keys which can be used for kms:decrypt
  kms_keys  = ["${module.global-kms.aws_kms_key_arn}", "${module.demo-kms.aws_kms_key_arn}"]

  # The SSM paths which are allowed to do kms:GetParameter and ssm:GetParametersByPath for
  #
  # https://medium.com/@tdi/ssm-parameter-store-for-keeping-secrets-in-a-structured-way-53a25d48166a
  # "arn:aws:ssm:region:123456:parameter/application/%s/*"
  #TODO
  ssm_paths = ["${module.global-kms.name}", "${module.demo-kms.name}"]

  # s3_ro_paths define which paths on S3 can be accessed from the ecs service in read-only fashion. 
  s3_ro_paths = []

  # s3_ro_paths define which paths on S3 can be accessed from the ecs service in read-write fashion. 
  s3_rw_paths = []

}
```

## Simple ECS Service on ECS with ALB Attached and no autoscaling

```hcl

module "demo-web" {
  source = "github.com/blinkist/airship-tf-ecs-service/"

  name   = "demo5-web"

  # 
  ecs_cluster_name = "${local.cluster_name}"
  fargate_enabled = true

  load_balancing_properties {
    lb_arn                = "${module.alb_shared_services_ext.load_balancer_id}"
    lb_listener_arn_https = "${element(module.alb_shared_services_ext.https_listener_arns,0)}"
    lb_listener_arn       = "${element(module.alb_shared_services_ext.http_tcp_listener_arns,0)}"
    lb_vpc_id             = "${module.vpc.vpc_id}"
    route53_zone_id       = "${aws_route53_zone.shared_ext_services_domain.zone_id}"
    unhealthy_threshold   = "3"
  }

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
  container_envvars  {
       SSM_ENABLED = "true"
       TASK_TYPE = "web" 
  } 

  # capacity_properties defines the size in task for the ECS Service.
  # Without scaling enabled, desired_capacity is the only necessary property
  # With scaling enabled, desired_min_capacity and desired_max_capacity define the lower and upper boundary in task size
  capacity_properties {
    desired_capacity     = "2"
  }

  # The KMS Keys which can be used for kms:decrypt
  kms_keys  = ["${module.global-kms.aws_kms_key_arn}", "${module.demo-kms.aws_kms_key_arn}"]

  # The SSM paths which are allowed to do kms:GetParameter and ssm:GetParametersByPath for
  ssm_paths = ["${module.global-kms.name}", "${module.demo-kms.name}"]

  # s3_ro_paths define which paths on S3 can be accessed from the ecs service in read-only fashion. 
  s3_ro_paths = []

  # s3_ro_paths define which paths on S3 can be accessed from the ecs service in read-write fashion. 
  s3_rw_paths = []

}

```



## Outputs

ecs_taskrole_arn - The ARN of the IAM Role for this task, can be used to add attach other IAM Permissions
