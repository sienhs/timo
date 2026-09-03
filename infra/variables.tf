variable "project_name" {
  description = "Resource name prefix"
  type        = string
  default     = "ticketing"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "primary_az" {
  description = "Primary AZ where the application, NAT instance, and Single-AZ RDS run"
  type        = string
  default     = "ap-northeast-2a"
}

variable "secondary_az" {
  description = "Secondary AZ used only for ALB and RDS subnet-group requirements"
  type        = string
  default     = "ap-northeast-2c"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "nat_instance_type" {
  description = "NAT instance type"
  type        = string
  default     = "t4g.nano"
}

variable "ec2_instance_type" {
  description = "Application EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  description = "Spring Boot application port"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "ALB target group health check path"
  type        = string
  default     = "/actuator/health"
}

variable "db_instance_class" {
  description = "Development RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  description = "Initial MySQL database name"
  type        = string
  default     = "ticketing"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "RDS password"
  type        = string
}
