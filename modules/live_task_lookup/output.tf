locals {
  empty_lookup = {
    environment        = ""
    image              = ""
    cpu                = ""
    memory             = ""
    memory_reservation = ""
    task_revision      = ""
  }

  safe_lambda_lookup = "${coalescelist(data.aws_lambda_invocation.lambda_lookup.*.result_map, list(local.empty_lookup))}"

  ## again extract first element of the list
  lambda_lookup = "${local.safe_lambda_lookup[0]}"

  environment_coalesce = "${coalescelist(data.aws_ecs_container_definition.lookup.*.environment, list(map()))}"
}

output "environment_json" {
  value = "${var.lookup_type == "lambda" ? 
              lookup(local.lambda_lookup, "environment", "") :
                ( var.lookup_type == "datasource" ?
                   jsonencode(local.environment_coalesce[0]) : "" )}"
}

output "image" {
  value = "${var.lookup_type == "lambda" ? 
                lookup(local.lambda_lookup, "image", "") : 
                  ( var.lookup_type == "datasource" ? 
                     element(concat(data.aws_ecs_container_definition.lookup.*.image, list("")), 0) : "" )}"
}

output "cpu" {
  value = "${var.lookup_type == "lambda" ? 
              lookup(local.lambda_lookup, "cpu", "") : 
                ( var.lookup_type == "datasource" ? 
                   element(concat(data.aws_ecs_container_definition.lookup.*.cpu, list("")), 0) : "" )}"
}

output "memory" {
  value = "${var.lookup_type == "lambda" ? 
              lookup(local.lambda_lookup, "memory", "") : 
                ( var.lookup_type == "datasource" ? 
                   element(concat(data.aws_ecs_container_definition.lookup.*.memory, list("")), 0) : "" )}"
}

output "memory_reservation" {
  value = "${var.lookup_type == "lambda" ? 
              lookup(local.lambda_lookup, "memory_reservation", "") : 
                ( var.lookup_type == "datasource" ? 
                   element(concat(data.aws_ecs_container_definition.lookup.*.memory_reservation, list("")), 0) : "" )}"
}

output "revision" {
  value = "${var.lookup_type == "lambda" ? 
              lookup(local.lambda_lookup, "task_revision", "") : 
                ( var.lookup_type == "datasource" ? 
                   element(concat(data.aws_ecs_task_definition.lookup.*.revision, list("")), 0) : "" )}"
}
