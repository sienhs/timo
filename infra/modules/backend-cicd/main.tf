data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  oidc_host              = trimprefix(var.gitlab_url, "https://")
  source_bucket_name     = "${var.name}-backend-source-${data.aws_caller_identity.current.account_id}"
  builder_project_name   = "${var.name}-backend-image"
  builder_project_arn    = "arn:${data.aws_partition.current.partition}:codebuild:${var.aws_region}:${data.aws_caller_identity.current.account_id}:project/${local.builder_project_name}"
  source_object_arn      = "${aws_s3_bucket.source.arn}/sources/*"
  gitlab_develop_subject = "project_path:${var.gitlab_project_path}:ref_type:branch:ref:develop"
}

resource "aws_s3_bucket" "source" {
  bucket        = local.source_bucket_name
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "source" {
  bucket                  = aws_s3_bucket.source.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "source" {
  bucket = aws_s3_bucket.source.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "source" {
  bucket = aws_s3_bucket.source.id
  rule {
    id     = "remove-transient-build-source"
    status = "Enabled"
    filter { prefix = "sources/" }
    expiration { days = 1 }
    abort_incomplete_multipart_upload { days_after_initiation = 1 }
  }
}

resource "aws_cloudwatch_log_group" "builder" {
  name              = "/aws/codebuild/${local.builder_project_name}"
  retention_in_days = 14
}

resource "aws_iam_role" "builder" {
  name = "${var.name}-backend-image-build"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "codebuild.amazonaws.com" }
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        ArnEquals    = { "aws:SourceArn" = local.builder_project_arn }
      }
    }]
  })
}

resource "aws_iam_role_policy" "builder" {
  role = aws_iam_role.builder.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = local.source_object_arn
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:BatchCheckLayerAvailability", "ecr:CompleteLayerUpload", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart"]
        Resource = var.ecr_repository_arn
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.builder.arn}:*"
      }
    ]
  })
}

resource "aws_codebuild_project" "builder" {
  name           = local.builder_project_name
  description    = "Builds the backend Dockerfile and pushes immutable images to ECR"
  service_role   = aws_iam_role.builder.arn
  build_timeout  = 30
  queued_timeout = 30

  artifacts { type = "NO_ARTIFACTS" }

  source {
    type     = "S3"
    location = "${aws_s3_bucket.source.bucket}/sources/placeholder.zip"
    buildspec = yamlencode({
      version = "0.2"
      phases = {
        pre_build = {
          commands = [
            "aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin ${split("/", var.ecr_repository_url)[0]}"
          ]
        }
        build = {
          commands = [
            "test -n \"$IMAGE_TAG\"",
            "cd backend/timo",
            "docker build --tag ${var.ecr_repository_url}:$IMAGE_TAG .",
            "docker push ${var.ecr_repository_url}:$IMAGE_TAG"
          ]
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
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
  }

  logs_config {
    cloudwatch_logs { group_name = aws_cloudwatch_log_group.builder.name }
  }

  depends_on = [aws_iam_role_policy.builder]
}

resource "aws_iam_openid_connect_provider" "gitlab" {
  url            = var.gitlab_url
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "gitlab_ci" {
  name = "${var.name}-backend-gitlab-ci"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.gitlab.arn }
      Condition = {
        StringEquals = {
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
          "${local.oidc_host}:sub" = local.gitlab_develop_subject
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "gitlab_ci" {
  role = aws_iam_role.gitlab_ci.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = local.source_object_arn
      },
      {
        Effect   = "Allow"
        Action   = ["codebuild:StartBuild", "codebuild:BatchGetBuilds", "codebuild:StopBuild"]
        Resource = aws_codebuild_project.builder.arn
      },
      {
        Effect = "Allow"
        Action = ["ssm:SendCommand"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}::document/AWS-RunShellScript",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/${var.ec2_instance_id}"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetCommandInvocation"]
        Resource = "*"
      }
    ]
  })
}
