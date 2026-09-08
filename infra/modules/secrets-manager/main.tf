resource "aws_secretsmanager_secret" "backend" {
  name                    = var.name
  description             = "Runtime environment variables for the backend container"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "backend" {
  secret_id     = aws_secretsmanager_secret.backend.id
  secret_string = var.secret_string
}
