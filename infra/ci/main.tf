data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  build_arn = "arn:${data.aws_partition.current.partition}:codebuild:${var.aws_region}:${data.aws_caller_identity.current.account_id}:project/${var.name}"
}

# Values are entered separately with set-secret.ps1. They never enter Terraform state.
resource "aws_secretsmanager_secret" "runner" {
  name                    = "${var.name}/runner-token"
  description             = "Authentication token of the existing project-only GitLab runner"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret" "webhook" {
  name                    = "${var.name}/webhook-token"
  description             = "Secret token configured in the GitLab project Job webhook"
  recovery_window_in_days = 7
}

resource "aws_cloudwatch_log_group" "build" {
  name              = "/aws/codebuild/${var.name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "webhook" {
  name              = "/aws/lambda/${var.name}-webhook"
  retention_in_days = 7
}

resource "aws_iam_role" "build" {
  name = "${var.name}-build"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "codebuild.amazonaws.com" }
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        ArnEquals    = { "aws:SourceArn" = local.build_arn }
      }
    }]
  })
}

resource "aws_iam_role_policy" "build" {
  role = aws_iam_role.build.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.build.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.runner.arn
      }
    ]
  })
}

resource "aws_codebuild_project" "runner" {
  name                   = var.name
  description            = "On-demand Docker executor for the existing GitLab CI (custom integration)"
  service_role           = aws_iam_role.build.arn
  build_timeout          = 60
  queued_timeout         = 60
  concurrent_build_limit = var.concurrent_build_limit

  artifacts {
    type = "NO_ARTIFACTS"
  }

  source {
    type = "NO_SOURCE"
    # The script is embedded in the project, so bootstrap never needs a repository clone.
    buildspec = yamlencode({
      version = "0.2"
      phases = {
        build = {
          commands = ["bash <<'TIMO_RUNNER_BOOTSTRAP'\n${file("${path.module}/runner.sh")}\nTIMO_RUNNER_BOOTSTRAP"]
        }
      }
    })
  }

  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/standard:7.0"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "GITLAB_URL"
      value = var.gitlab_url
    }
    environment_variable {
      name  = "RUNNER_VERSION"
      value = var.runner_version
    }
    environment_variable {
      name  = "RUNNER_TOKEN"
      value = aws_secretsmanager_secret.runner.arn
      type  = "SECRETS_MANAGER"
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.build.name
    }
  }

  depends_on = [aws_iam_role_policy.build]
}

resource "aws_dynamodb_table" "jobs" {
  name         = "${var.name}-jobs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "job_key"

  attribute {
    name = "job_key"
    type = "S"
  }

  # Retain deduplication records: an expired record could restart an old job's worker.
}

resource "aws_iam_role" "webhook" {
  name = "${var.name}-webhook"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "webhook" {
  role = aws_iam_role.webhook.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.webhook.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.webhook.arn
      },
      {
        Effect   = "Allow"
        Action   = ["codebuild:StartBuild"]
        Resource = aws_codebuild_project.runner.arn
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"]
        Resource = aws_dynamodb_table.jobs.arn
      }
    ]
  })
}

data "archive_file" "webhook" {
  # Build first: go -C infra/ci/webhook run ./cmd/build
  # Preserve this archive between plan and apply.
  type             = "zip"
  source_file      = "${path.module}/.build/bootstrap"
  output_file_mode = "0755"
  output_path      = "${path.module}/.build/webhook.zip"
}

resource "aws_lambda_function" "webhook" {
  function_name    = "${var.name}-webhook"
  role             = aws_iam_role.webhook.arn
  runtime          = "provided.al2023"
  architectures    = ["arm64"]
  handler          = "bootstrap"
  filename         = data.archive_file.webhook.output_path
  source_code_hash = data.archive_file.webhook.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      CODEBUILD_PROJECT  = aws_codebuild_project.runner.name
      GITLAB_PROJECT_ID  = tostring(var.gitlab_project_id)
      WEBHOOK_SECRET_ARN = aws_secretsmanager_secret.webhook.arn
      WEBHOOK_ENABLED    = tostring(var.webhook_enabled)
      JOB_TABLE          = aws_dynamodb_table.jobs.name
    }
  }

  depends_on = [aws_iam_role_policy.webhook]
}

resource "aws_lambda_function_url" "webhook" {
  function_name      = aws_lambda_function.webhook.function_name
  authorization_type = "NONE"
}

# GitLab cannot sign AWS IAM requests. The Go handler authenticates X-Gitlab-Token.
# Both permissions are required for new Function URLs (AWS change, October 2025).
resource "aws_lambda_permission" "url" {
  statement_id           = "AllowPublicFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.webhook.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "url_invoke" {
  statement_id             = "AllowInvocationOnlyThroughUrl"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.webhook.function_name
  principal                = "*"
  invoked_via_function_url = true
}
