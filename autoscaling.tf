locals {
   cluster_plus_service_name = "${local.cluster_name}-${local.ecs_service_name}"
   ecs_service_name = "${local.awsvpc_enabled ? join("",aws_ecs_service.app-with-lb-awsvpc.*.name) : join("",aws_ecs_service.app-with-lb.*.name) }"
}

resource "aws_appautoscaling_target" "target" {
  count              = "${local.scaling_enabled ? 1 : 0}"
  service_namespace  = "ecs"
  resource_id        = "service/${local.cluster_name}/${local.ecs_service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = "${local.desired_min_capacity}"
  max_capacity       = "${local.desired_max_capacity}"
}

resource "aws_appautoscaling_policy" "policy" {
  count = "${(local.scaling_enabled ? 1 : 0 ) * length(var.scaling_properties)}"

  name               = "${local.cluster_plus_service_name}-${lookup(var.scaling_properties[count.index], "type")}-${element(var.direction[lookup(var.scaling_properties[count.index], "direction")],1)}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  resource_id        = "service/${local.cluster_name}/${local.ecs_service_name}"

  step_scaling_policy_configuration {
    adjustment_type         = "${lookup(var.scaling_properties[count.index], "adjustment_type")}"
    cooldown                = "${lookup(var.scaling_properties[count.index], "cooldown")}"
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = "${lookup(var.scaling_properties[count.index], "scaling_adjustment")}"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "service_low" {
  count = "${(local.scaling_enabled ? 1 : 0 ) * length(var.scaling_properties)}"
  alarm_name = "${local.cluster_plus_service_name}-${lookup(var.scaling_properties[count.index], "type")}-${element(var.direction[lookup(var.scaling_properties[count.index], "direction")],1)}"

  comparison_operator = "${element(var.direction[lookup(var.scaling_properties[count.index], "direction")],0)}"

  evaluation_periods = "${lookup(var.scaling_properties[count.index], "evaluation_periods")}"
  metric_name        = "${lookup(var.scaling_properties[count.index], "type")}"
  namespace          = "AWS/ECS"
  period             = "${lookup(var.scaling_properties[count.index], "observation_period")}"
  statistic          = "${lookup(var.scaling_properties[count.index], "statistic")}"
  threshold          = "${lookup(var.scaling_properties[count.index], "threshold")}"

  dimensions {
    ClusterName = "${local.cluster_name}"
    ServiceName = "${local.ecs_service_name}"
  }

  alarm_actions = ["${aws_appautoscaling_policy.policy.*.arn[count.index]}"]
}
