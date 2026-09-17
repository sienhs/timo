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

# The agent publishes host-level metrics that EC2's built-in metrics do not
# include, notably memory, disk utilisation, and swap usage.
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
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

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "tracing_endpoint_read" {
  name = "${var.name}-tracing-endpoint-read"
  role = aws_iam_role.ssm.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.name}/tracing/endpoint"
    }]
  })
}

resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.this.name
  monitoring                  = var.detailed_monitoring

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  # The public SSM parameter always advances to the newest AL2023 AMI. Do not
  # replace a running application instance during an unrelated Terraform apply.
  # AMI upgrades are performed explicitly in a planned maintenance change.
  lifecycle {
    ignore_changes = [ami]
  }

  user_data = replace(<<-EOF
              #!/bin/bash
              set -eux
              # AL2023 already supplies curl-minimal; installing curl conflicts with it.
              dnf install -y docker python3
              dnf install -y amazon-cloudwatch-agent
              systemctl enable --now docker
              install -d -m 0755 /opt/timo /var/lib/timo
              cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWAGENT'
              {
                "agent": { "metrics_collection_interval": 60, "run_as_user": "root" },
                "metrics": {
                  "namespace": "Timo/EC2",
                  "aggregation_dimensions": [["InstanceId"]],
                  "append_dimensions": {
                    "InstanceId": "$${aws:InstanceId}",
                    "ImageId": "$${aws:ImageId}",
                    "InstanceType": "$${aws:InstanceType}"
                  },
                  "metrics_collected": {
                    "cpu": { "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_system", "cpu_usage_user"], "totalcpu": true },
                    "mem": { "measurement": ["mem_used_percent"] },
                    "disk": { "measurement": ["used_percent"], "resources": ["/"] },
                    "swap": { "measurement": ["swap_used_percent"] },
                    "net": { "measurement": ["bytes_sent", "bytes_recv"] }
                  }
                }
              }
              CWAGENT
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                -a fetch-config -m ec2 \
                -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
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

              required = ("SPRING_PROFILES_ACTIVE", "DB_URL", "DB_USERNAME", "DB_PASSWORD", "JWT_SECRET", "ENTRY_PASS_SECRET", "WALLET_MASTER_KEY",
                          "ADMIN_PRIVATE_KEY", "SOLAPI_API_KEY", "SOLAPI_API_SECRET", "SOLAPI_SENDER_PHONE", "SMS_LIVE_TEST_TO",
                          "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_REGION", "S3_PUBLIC_BUCKET_NAME", "IMAGE_BASE_URL")
              values = json.load(open(os.environ["SECRET_FILE"], encoding="utf-8"))
              for key in required:
                  value = values.get(key)
                  if not isinstance(value, str) or not value or "\n" in value or "\r" in value:
                      sys.exit(f"Invalid or missing secret value: {key}")
                  print(f"{key}={value}")
              PY
              chmod 0600 /etc/timo/backend.env
              tracing_endpoint=$(aws ssm get-parameter --region ${var.aws_region} \
                --name '/${var.name}/tracing/endpoint' --query Parameter.Value --output text)
              printf 'TRACING_OTLP_ENDPOINT=%s\n' "$tracing_endpoint" >>/etc/timo/backend.env

              registry=$${image%%/*}
              aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin "$registry"
              # Preserve images referenced by the running/rollback containers while
              # removing stale releases before the next image is unpacked.
              docker image prune --all --force
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
                  # Once the replacement is healthy, retain only images referenced
                  # by existing containers so old release layers do not accumulate.
                  docker image prune --all --force
                  trap - ERR
                  exit 0
                fi
                sleep 2
              done
              # Keep the application failure visible to the SSM caller before
              # rollback removes the failed replacement container.  The CI job
              # collects StandardErrorContent on a failed command invocation.
              echo "Backend health check did not become ready; replacement container logs:" >&2
              docker logs --tail 200 timo-backend >&2 || true
              echo "Replacement container state:" >&2
              docker inspect --format '{{json .State}}' timo-backend >&2 || true
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

# RDS does not accept a schema file as part of aws_db_instance creation. Run
# the versioned SQL from the private application instance instead, after the
# instance can read the existing DB secret. This avoids exposing DB credentials
# in Terraform state or opening MySQL to the CI runner.
resource "aws_ssm_document" "rds_schema_bootstrap" {
  name            = "${var.name}-rds-schema-bootstrap"
  document_type   = "Command"
  document_format = "JSON"

  # SSM runs this as a Linux shell script.  Terraform on Windows can preserve
  # CRLF inside the heredoc, which makes the shebang resolve as `bash\r`.
  content = replace(jsonencode({
    schemaVersion = "2.2"
    description   = "Initialise the Timo RDS schema and load test members"
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "initialiseRds"
      inputs = {
        timeoutSeconds = "1800"
        runCommand = [replace(<<-SCRIPT
          #!/usr/bin/env bash
          set -euo pipefail

          dnf install -y mariadb105

          secret_file=$(mktemp)
          env_file=$(mktemp)
          sql_file=$(mktemp)
          drop_file=$(mktemp)
          trap 'rm -f "$secret_file" "$env_file" "$sql_file" "$drop_file"' EXIT

          aws secretsmanager get-secret-value \
            --region ${var.aws_region} \
            --secret-id '${var.backend_secret_arn}' \
            --query SecretString \
            --output text >"$secret_file"

          SECRET_FILE="$secret_file" python3 - <<'PY' >"$env_file"
          import json
          import os
          import shlex
          import sys

          values = json.load(open(os.environ["SECRET_FILE"], encoding="utf-8"))
          for key in ("DB_USERNAME", "DB_PASSWORD"):
              value = values.get(key)
              if not isinstance(value, str) or not value or "\n" in value or "\r" in value:
                  sys.exit(f"Invalid or missing secret value: {key}")
              print(f"{key}={shlex.quote(value)}")
          PY

          set -a
          source "$env_file"
          set +a
          printf '%s' '${var.db_init_sql_base64}' | base64 --decode >"$sql_file"

          mysql_cmd=(
            mysql
            --protocol=TCP
            --connect-timeout=5
            --host='${var.db_endpoint}'
            --port='${var.db_port}'
            --user="$DB_USERNAME"
            --database='${var.db_name}'
          )

          for attempt in $(seq 1 60); do
            if existing_tables=$(MYSQL_PWD="$DB_PASSWORD" "$${mysql_cmd[@]}" --skip-column-names \
              --execute="SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE()"); then
              break
            fi
            sleep 10
          done

          if [[ -z "$${existing_tables:-}" ]]; then
            echo 'RDS did not accept connections within 10 minutes.' >&2
            exit 1
          fi

          if [[ "$existing_tables" != "0" ]]; then
            echo "Resetting database: removing $existing_tables existing tables."
            MYSQL_PWD="$DB_PASSWORD" "$${mysql_cmd[@]}" --skip-column-names --batch \
              --execute="
                SELECT CONCAT(
                  'DROP TABLE IF EXISTS ',
                  CHAR(96),
                  REPLACE(table_name, CHAR(96), CONCAT(CHAR(96), CHAR(96))),
                  CHAR(96),
                  ';'
                )
                FROM information_schema.tables
                WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE'
              " >"$drop_file"

            {
              echo 'SET FOREIGN_KEY_CHECKS = 0;'
              cat "$drop_file"
              echo 'SET FOREIGN_KEY_CHECKS = 1;'
            } | MYSQL_PWD="$DB_PASSWORD" "$${mysql_cmd[@]}"
          fi

          MYSQL_PWD="$DB_PASSWORD" "$${mysql_cmd[@]}" <"$sql_file"

          member_count=$(MYSQL_PWD="$DB_PASSWORD" "$${mysql_cmd[@]}" --skip-column-names \
            --execute="SELECT COUNT(*) FROM member")
          [[ "$member_count" == "100000" ]] || {
            echo "Expected 100000 load-test members, found $member_count." >&2
            exit 1
          }
          exit 0

          SCRIPT
        , "\r", "")]
      }
    }]
  }), "\r", "")
}

# The association has no schedule and normally runs only when it is created.
# Make the SQL content an explicit replacement trigger so a changed init file
# always produces a fresh association execution and a reproducible test DB.
resource "terraform_data" "rds_schema_revision" {
  triggers_replace = [sha256(var.db_init_sql_base64)]
}

resource "aws_ssm_association" "rds_schema_bootstrap" {
  name             = aws_ssm_document.rds_schema_bootstrap.name
  association_name = "${var.name}-rds-schema-bootstrap"
  document_version = "$LATEST"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.this.id]
  }

  wait_for_success_timeout_seconds = 1800

  lifecycle {
    replace_triggered_by = [terraform_data.rds_schema_revision]
  }
}
