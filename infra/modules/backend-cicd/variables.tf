variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "aws_region" {
  type = string
}

variable "ecr_repository_arn" {
  type = string
}

variable "ecr_repository_url" {
  type = string
}

variable "ec2_instance_id" {
  type = string
}

variable "gitlab_url" {
  description = "GitLab issuer URL used by GitLab CI OIDC tokens"
  type        = string
}

variable "gitlab_project_path" {
  description = "Exact GitLab project path, for example group/project"
  type        = string
}
