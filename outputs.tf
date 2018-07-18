output "ecs_taskrole_arn" {
  value = "${module.iam.ecs_taskrole_arn}"
}

output "lb_target_group_arn" {
  value = "${module.alb_handling.lb_target_group_arn}"
}
