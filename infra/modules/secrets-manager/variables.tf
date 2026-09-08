variable "name" {
  description = "Name of the backend application secret"
  type        = string
}

variable "secret_string" {
  description = "JSON object consumed as Docker environment variables"
  type        = string
  sensitive   = true
}
