README


## Usage without ECS Scaling

```hcl

module "demo-web" {
  source = "github.com/blinkist/airship-tf-ecs-service/"

  name   = "demo-web"

  ecs_properties {
    ecs_cluster_name    = "${local.cluster_name}"
    service_launch_type = "FARGATE"
    memory              = "512"
    cpu                 = "256"
  }

  awsvpc_enabled            = true
  awsvpc_subnets            = ["${module.vpc.private_subnets}"]
  awsvpc_security_group_ids = ["${module.demo_sg.this_security_group_id}"]

  load_balancing_properties {
    alb_attached          = true
    lb_arn                = "${module.alb_shared_services_ext.load_balancer_id}"
    lb_listener_arn_https = "${element(module.alb_shared_services_ext.https_listener_arns,0)}"
    lb_listener_arn       = "${element(module.alb_shared_services_ext.http_tcp_listener_arns,0)}"
    lb_priority           = "100"
    lb_vpc_id             = "${module.vpc.vpc_id}"
    route53_zone_id       = "${aws_route53_zone.shared_ext_services_domain.zone_id}"
  }

  container_properties = [{
    image_url  = "861769473120.dkr.ecr.eu-central-1.amazonaws.com/demo:latest"
    port       = "3000"
    health_uri = "/ping"
    mem        = "512"
    cpu        = "256"
  }]

  capacity_properties {
    desired_capacity     = "2"
    desired_min_capacity = "2"
    desired_max_capacity = "5"
  }

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

  kms_keys  = ["${module.global-kms.aws_kms_key_arn}", "${module.demo-kms.aws_kms_key_arn}"]
  ssm_paths = ["${module.global-kms.name}", "${module.demo-kms.name}"]
}}
```

## Outputs

TODO

