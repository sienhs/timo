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

variable "ec2_detailed_monitoring" {
  description = "Enable one-minute EC2 built-in CloudWatch metrics; this incurs AWS detailed-monitoring charges."
  type        = bool
  default     = true
}

variable "monitoring_instance_type" {
  description = "Private EC2 instance type for the Prometheus and Grafana containers"
  type        = string
  default     = "t3.small"
}

variable "monitoring_root_volume_size" {
  description = "Encrypted gp3 root volume size in GiB; holds retained Prometheus and Grafana data"
  type        = number
  default     = 30
}

variable "grafana_admin_password" {
  description = "Initial Grafana administrator password; set only in ignored terraform.tfvars"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.grafana_admin_password) >= 16
    error_message = "grafana_admin_password must be at least 16 characters."
  }
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
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT HS256 signing key. Use at least 32 random bytes."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.jwt_secret) >= 32 && !startswith(var.jwt_secret, "REPLACE_WITH_")
    error_message = "Set jwt_secret to a random value of at least 32 characters; do not leave the example value."
  }
}

variable "wallet_master_key" {
  description = "Backend wallet encryption master key (32 bytes encoded as 64 hexadecimal characters)."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9a-fA-F]{64}$", var.wallet_master_key))
    error_message = "wallet_master_key must be exactly 64 hexadecimal characters."
  }
}

variable "admin_private_key" {
  description = "Blockchain administrator private key (0x-prefixed 32-byte hexadecimal value)."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^0x[0-9a-fA-F]{64}$", var.admin_private_key))
    error_message = "admin_private_key must be 0x followed by exactly 64 hexadecimal characters."
  }
}

variable "gitlab_project_path" {
  description = "Exact GitLab project path, for example group/project"
  type        = string

  validation {
    condition     = can(regex("^[^:/\\s]+(/[^:/\\s]+)+$", var.gitlab_project_path))
    error_message = "Use group/project only, without https:// or a hostname."
  }
}

variable "solapi_environment" {
  description = "SolAPI credentials, registered sender and opt-in live-test recipient"
  type = object({
    SOLAPI_API_KEY      = string
    SOLAPI_API_SECRET   = string
    SOLAPI_SENDER_PHONE = string
    SMS_LIVE_TEST_TO    = string
  })
  sensitive = true
}

variable "domain_name" {
  description = "Domain managed by the independent DNS root"
  type        = string
  default     = "ticketmoa.site"
}

variable "grafana_subdomain" {
  description = "Subdomain used for the public Grafana HTTPS endpoint"
  type        = string
  default     = "grafana"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.grafana_subdomain))
    error_message = "grafana_subdomain must be a lowercase DNS label."
  }
}
