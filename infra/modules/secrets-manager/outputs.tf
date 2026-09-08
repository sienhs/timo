output "arn" {
  description = "ARN of the backend runtime secret"
  value       = aws_secretsmanager_secret.backend.arn
}
