variable "name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "app_port" {
  type = number
}

variable "aws_region" {
  type = string
}

variable "backend_secret_arn" {
  description = "Secrets Manager secret containing backend Docker environment variables"
  type        = string
}
