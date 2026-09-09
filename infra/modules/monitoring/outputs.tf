output "instance_id" {
  value = aws_instance.this.id
}

output "private_ip" {
  value = aws_instance.this.private_ip
}

output "grafana_secret_arn" {
  description = "Secrets Manager secret containing the Grafana administrator password"
  value       = aws_secretsmanager_secret.grafana.arn
}
