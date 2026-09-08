data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_iam_role" "ssm" {
  name = "${var.name}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ecr_pull" {
  name = "${var.name}-ecr-pull"
  role = aws_iam_role.ssm.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:GetAuthorizationToken"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "backend_secret_read" {
  name = "${var.name}-backend-secret-read"
  role = aws_iam_role.ssm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.backend_secret_arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-ec2-profile"
  role = aws_iam_role.ssm.name
}

resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.this.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  user_data = replace(<<-EOF
              #!/bin/bash
              set -eux
              # AL2023 already supplies curl-minimal; installing curl conflicts with it.
              dnf install -y docker python3
              systemctl enable --now docker
              install -d -m 0755 /opt/timo /var/lib/timo
              cat >/opt/timo/deploy.sh <<'SCRIPT'
              #!/usr/bin/env bash
              set -euo pipefail

              image=$${1:?Image URI is required}
              pipeline=$${2:?Pipeline IID is required}
              [[ "$image" =~ ^[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com/.+:[a-f0-9]+-[0-9]+$ ]]
              [[ "$pipeline" =~ ^[0-9]+$ ]]

              exec 9>/var/lib/timo/deploy.lock
              flock -w 30 9
              last=$(cat /var/lib/timo/pipeline 2>/dev/null || echo 0)
              (( pipeline >= last )) || { echo "Outdated pipeline" >&2; exit 1; }

              secret_file=$(mktemp)
              trap 'rm -f "$secret_file"' EXIT
              aws secretsmanager get-secret-value \
                --region ${var.aws_region} \
                --secret-id '${var.backend_secret_arn}' \
                --query SecretString \
                --output text >"$secret_file"
              install -d -m 0700 /etc/timo
              SECRET_FILE="$secret_file" python3 - <<'PY' >/etc/timo/backend.env
              import json
              import os
              import sys

              required = ("SPRING_PROFILES_ACTIVE", "DB_URL", "DB_USERNAME", "DB_PASSWORD", "JWT_SECRET",
                          "SOLAPI_API_KEY", "SOLAPI_API_SECRET", "SOLAPI_SENDER_PHONE", "SMS_LIVE_TEST_TO")
              values = json.load(open(os.environ["SECRET_FILE"], encoding="utf-8"))
              for key in required:
                  value = values.get(key)
                  if not isinstance(value, str) or not value or "\n" in value or "\r" in value:
                      sys.exit(f"Invalid or missing secret value: {key}")
                  print(f"{key}={value}")
              PY
              chmod 0600 /etc/timo/backend.env

              registry=$${image%%/*}
              aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin "$registry"
              docker pull "$image"

              previous=false
              if docker container inspect timo-backend >/dev/null 2>&1; then
                docker rm -f timo-backend-previous >/dev/null 2>&1 || true
                docker rename timo-backend timo-backend-previous
                docker stop --time 30 timo-backend-previous >/dev/null
                previous=true
              fi

              rollback() {
                trap - ERR
                docker rm -f timo-backend >/dev/null 2>&1 || true
                if "$previous"; then
                  docker rename timo-backend-previous timo-backend
                  docker start timo-backend >/dev/null
                fi
                exit 1
              }
              trap rollback ERR

              docker run -d --name timo-backend --restart unless-stopped \
                --env-file /etc/timo/backend.env \
                --publish ${var.app_port}:${var.app_port} \
                --log-driver json-file --log-opt max-size=10m --log-opt max-file=3 \
                "$image" >/dev/null

              for attempt in {1..60}; do
                if curl --fail --silent --max-time 3 http://127.0.0.1:${var.app_port}/actuator/health >/dev/null; then
                  printf '%s\n' "$pipeline" >/var/lib/timo/pipeline
                  docker rm -f timo-backend-previous >/dev/null 2>&1 || true
                  trap - ERR
                  exit 0
                fi
                sleep 2
              done
              false
              SCRIPT
              chmod 0755 /opt/timo/deploy.sh
              EOF
  , "\r\n", "\n")

  tags = {
    Name = "${var.name}-app"
  }
}

# Existing instances do not re-run cloud-init when user_data changes. This
# association applies the same Docker and deployment-script setup to EC2 that
# already existed before this CI/CD configuration was added.
resource "aws_ssm_association" "backend_bootstrap" {
  name             = "AWS-RunShellScript"
  association_name = "${var.name}-backend-bootstrap"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.this.id]
  }

  parameters = {
    commands = aws_instance.this.user_data
  }
}
