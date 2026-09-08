output "repository_url" {
  description = "Repository URL for pushing and pulling container images"
  value       = aws_ecr_repository.this.repository_url
}

output "arn" {
  description = "ECR repository ARN for IAM policies"
  value       = aws_ecr_repository.this.arn
}
