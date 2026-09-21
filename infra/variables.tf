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
  default     = "t4g.micro"
}

variable "ec2_instance_type" {
  description = "Application EC2 instance type; sized for Spring Boot and synchronous web3j blockchain RPC calls"
  type        = string
  default     = "t3.medium"
}

variable "ec2_root_volume_size" {
  description = "Encrypted gp3 root volume size in GiB for the application EC2 instance"
  type        = number
  default     = 30

  validation {
    condition     = var.ec2_root_volume_size >= 20
    error_message = "ec2_root_volume_size must be at least 20 GiB."
  }
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

variable "redis_node_type" {
  description = "Development ElastiCache Redis node type"
  type        = string
  default     = "cache.t4g.micro"
}

variable "redis_engine_version" {
  description = "Redis engine version for ElastiCache"
  type        = string
  default     = "7.1"
}

variable "redis_port" {
  description = "Redis listener port"
  type        = number
  default     = 6379
}

variable "redis_auth_token" {
  description = "Redis AUTH token; set only in ignored terraform.tfvars"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.redis_auth_token) >= 16 && length(var.redis_auth_token) <= 128 && can(regex("^[^/@\"]+$", var.redis_auth_token))
    error_message = "redis_auth_token must be 16-128 characters and cannot contain '/', '@', or a double quote."
  }
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

variable "entry_pass_secret" {
  description = "QR entry-pass signing secret."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.entry_pass_secret) >= 32 && !startswith(var.entry_pass_secret, "REPLACE_WITH_")
    error_message = "Set entry_pass_secret to a random value of at least 32 characters; do not leave the example value."
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

variable "firebase_service_account_json_base64" {
  description = "Base64-encoded Firebase service-account JSON. Supply only with TF_VAR_firebase_service_account_json_base64; never commit it."
  type        = string
  sensitive   = true

  validation {
    condition     = can(base64decode(var.firebase_service_account_json_base64))
    error_message = "firebase_service_account_json_base64 must be valid Base64."
  }
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
