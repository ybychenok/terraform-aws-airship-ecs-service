variable "create" {
  default = true
}

variable "region" {
  default = ""
}

variable "name" {
  default = ""
}

variable "fargate_enabled" {
  default = false
}

# List of KMS keys the task has access to
variable "kms_keys" {
  default = []
}

# List of SSM Paths the task has access to
variable "ssm_paths" {
  default = []
}

# S3 Read-only paths the Task has access to
variable "s3_ro_paths" {
  default = []
}

# S3 Read-write paths the Task has access to
variable "s3_rw_paths" {
  default = []
}
