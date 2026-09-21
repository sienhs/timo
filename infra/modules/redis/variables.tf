variable "name" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnets used by the ElastiCache subnet group."
  type        = list(string)
}

variable "security_group_id" {
  type = string
}

variable "node_type" {
  description = "ElastiCache node type."
  type        = string
}

variable "engine_version" {
  description = "Redis engine version."
  type        = string
}

variable "port" {
  type = number
}

variable "auth_token" {
  description = "Redis AUTH token. Stored in the backend runtime secret."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.auth_token) >= 16 && length(var.auth_token) <= 128 && can(regex("^[^/@\"]+$", var.auth_token))
    error_message = "redis_auth_token must be 16-128 characters and cannot contain '/', '@', or a double quote."
  }
}
