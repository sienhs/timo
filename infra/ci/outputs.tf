output "codebuild_project_name" {
  value = aws_codebuild_project.runner.name
}

output "webhook_url" {
  description = "GitLab Settings > Webhooks: use this URL, Secret token, and Job events."
  value       = aws_lambda_function_url.webhook.function_url
}

output "runner_secret_arn" {
  value = aws_secretsmanager_secret.runner.arn
}

output "webhook_secret_arn" {
  value = aws_secretsmanager_secret.webhook.arn
}

output "aws_region" {
  value = var.aws_region
}
