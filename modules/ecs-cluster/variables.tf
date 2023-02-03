variable "app_name" {
  default = "oms"
}

variable "execution_role_arn" {
  default = "arn:aws:iam::405002847291:role/ecsTaskExecutionRole"
}

variable "public_subnets" {}

variable "private_subnets" {}

variable "aws_vpc" {}

variable "container_port" {
  default = 8080
}