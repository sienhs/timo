variable "name" {
  type = string
}

variable "jaeger_security_group_id" {
  type = string
}

variable "jaeger_image" {
  type    = string
  default = "cr.jaegertracing.io/jaegertracing/jaeger:2.20.0"
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

variable "root_volume_size" {
  type = number
}

variable "aws_region" {
  type = string
}

variable "application_private_ip" {
  description = "Private IP address of the Spring Boot scrape target"
  type        = string
}

variable "application_instance_id" {
  description = "Application EC2 instance ID displayed in Grafana CloudWatch panels"
  type        = string
}

variable "rds_instance_identifier" {
  description = "RDS DB instance identifier displayed in Grafana CloudWatch panels"
  type        = string
}

variable "grafana_admin_password" {
  description = "Initial Grafana admin password; provide this through an ignored terraform.tfvars file"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.grafana_admin_password) >= 16
    error_message = "grafana_admin_password must be at least 16 characters."
  }
}

variable "prometheus_image" {
  type    = string
  default = "prom/prometheus:v3.14.0"
}

variable "grafana_image" {
  type    = string
  default = "grafana/grafana:13.2.1"
}

variable "grafana_domain" {
  description = "Public HTTPS hostname served through the ALB"
  type        = string
}
