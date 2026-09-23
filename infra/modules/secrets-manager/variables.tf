variable "name" {
  description = "Name of the backend application secret"
  type        = string
}

variable "secret_string" {
  description = "JSON patch for Docker environment variables; existing keys are retained"
  type        = string
  sensitive   = true
}
