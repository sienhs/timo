variable "name" {
  type = string
}

variable "certificate_arn" {
  description = "Validated ACM certificate in the ALB region"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "target_instance_id" {
  type = string
}

variable "app_port" {
  type = number
}

variable "health_check_path" {
  type = string
}
