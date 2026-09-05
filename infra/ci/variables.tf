variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "name" {
  type    = string
  default = "timo-gitlab-runner"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,39}$", var.name))
    error_message = "Use 3-40 lowercase letters, numbers, or hyphens."
  }
}

variable "gitlab_project_id" {
  description = "Numeric ID of S15P21D206 (not the project path)."
  type        = number
  validation {
    condition     = var.gitlab_project_id > 0 && floor(var.gitlab_project_id) == var.gitlab_project_id
    error_message = "Enter the positive numeric GitLab project ID."
  }
}

variable "gitlab_url" {
  type    = string
  default = "https://lab.ssafy.com"
  validation {
    condition     = can(regex("^https://[A-Za-z0-9.-]+(:[0-9]+)?$", var.gitlab_url))
    error_message = "Use an HTTPS GitLab origin without a trailing slash or credentials."
  }
}

variable "runner_version" {
  description = "Pinned upstream Runner release; check compatibility with the GitLab server before changing."
  type        = string
  default     = "19.3.1"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.runner_version))
    error_message = "Use a stable version such as 19.3.1."
  }
}

variable "concurrent_build_limit" {
  description = "Maximum simultaneous job workers. Default allows six frontend/backend/Terraform jobs plus four overlapping jobs; keep within the regional Linux/Small quota."
  type        = number
  default     = 10
  validation {
    condition     = var.concurrent_build_limit >= 1 && floor(var.concurrent_build_limit) == var.concurrent_build_limit
    error_message = "Use a positive integer within the AWS regional Linux/Small concurrent build quota."
  }
}

variable "webhook_enabled" {
  description = "Enable only after both secret values are stored and a manual CodeBuild run succeeds."
  type        = bool
  default     = false
}
