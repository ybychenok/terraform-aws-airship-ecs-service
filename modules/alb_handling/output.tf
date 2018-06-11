output "lb_target_group_arn" {
  value = "${element(concat(aws_lb_target_group.service.*.arn, list("")), 0)}"
}
