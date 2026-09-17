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

variable "root_volume_size" {
  description = "Encrypted gp3 root volume size in GiB"
  type        = number
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

variable "db_endpoint" {
  description = "RDS endpoint used by the one-time schema bootstrap command"
  type        = string
}

variable "db_port" {
  description = "RDS MySQL port used by the one-time schema bootstrap command"
  type        = number
}

variable "db_name" {
  description = "Database to initialise"
  type        = string
}

variable "db_init_sql_base64" {
  description = "Base64-encoded SQL executed once through SSM after RDS provisioning"
  type        = string
  sensitive   = true
}

variable "detailed_monitoring" {
  description = "Publish EC2 instance metrics to CloudWatch at one-minute resolution"
  type        = bool
  default     = true
}
