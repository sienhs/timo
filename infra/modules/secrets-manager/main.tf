resource "aws_secretsmanager_secret" "backend" {
  name                    = var.name
  description             = "Runtime environment variables for the backend container"
  recovery_window_in_days = 7
}

# Keep any runtime variables that predate Terraform (or were set manually).
# The configured values in secret_string still take precedence when a key is
# intentionally managed here.
data "aws_secretsmanager_secret_version" "current" {
  secret_id     = aws_secretsmanager_secret.backend.id
  version_stage = "AWSCURRENT"
}

resource "aws_secretsmanager_secret_version" "backend" {
  secret_id     = aws_secretsmanager_secret.backend.id
  secret_string = jsonencode(merge(
    try(jsondecode(data.aws_secretsmanager_secret_version.current.secret_string), {}),
    jsondecode(var.secret_string),
  ))
}
