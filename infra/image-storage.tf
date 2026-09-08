data "aws_caller_identity" "image_storage" {}

locals {
  image_bucket_name = "${var.project_name}-${var.environment}-images-${data.aws_caller_identity.image_storage.account_id}"
}

resource "aws_s3_bucket" "images" {
  bucket        = local.image_bucket_name
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket                  = aws_s3_bucket.images.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "images" {
  bucket = aws_s3_bucket.images.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowImageCloudFrontRead"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.images.arn}/*"
      Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.images.arn } }
      }, {
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.images.arn, "${aws_s3_bucket.images.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

resource "aws_iam_user" "image_storage" {
  name = "${var.project_name}-${var.environment}-image-storage"
}

resource "aws_iam_user_policy" "image_storage" {
  name = "image-bucket-access"
  user = aws_iam_user.image_storage.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:ListBucketMultipartUploads"]
        Resource = aws_s3_bucket.images.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
          "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"
        ]
        Resource = "${aws_s3_bucket.images.arn}/*"
      }
    ]
  })
}

resource "aws_iam_access_key" "image_storage" {
  user = aws_iam_user.image_storage.name

  depends_on = [aws_iam_user_policy.image_storage]
}

output "image_bucket_name" {
  value = aws_s3_bucket.images.id
}

output "image_storage_credentials" {
  description = "Backend credentials; export to a private file, never commit"
  sensitive   = true
  value = {
    AWS_ACCESS_KEY_ID     = aws_iam_access_key.image_storage.id
    AWS_SECRET_ACCESS_KEY = aws_iam_access_key.image_storage.secret
    AWS_REGION            = var.aws_region
    S3_BUCKET_NAME        = aws_s3_bucket.images.id
  }
}
