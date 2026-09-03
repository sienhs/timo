variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "private_route_table_id" {
  type = string
}

variable "private_app_subnet_cidr" {
  type = string
}

variable "instance_type" {
  type = string
}
