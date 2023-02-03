variable "app_name" {
  default = "oms"
}

variable "execution_role_arn" {
  default = "arn:aws:iam::250117035524:role/ecsTaskExecutionRole"
}

variable "public_subnets" {}

variable "private_subnets" {}

variable "aws_vpc" {}

variable "container_port" {
  default = 8080
}