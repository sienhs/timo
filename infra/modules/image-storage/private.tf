resource "aws_s3_bucket" "private_images" {
  bucket        = "${var.project_name}-${var.environment}-private-images-${data.aws_caller_identity.image_storage.account_id}"
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "private_images" {
  bucket                  = aws_s3_bucket.private_images.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "private_images" {
  bucket = aws_s3_bucket.private_images.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "private_images" {
  bucket = aws_s3_bucket.private_images.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "private_images" {
  bucket = aws_s3_bucket.private_images.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.private_images.arn, "${aws_s3_bucket.private_images.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

# Cross-origin reads still require a valid signature; this grants no public access.
resource "aws_s3_bucket_cors_configuration" "private_images" {
  bucket = aws_s3_bucket.private_images.id
  cors_rule {
    allowed_origins = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_headers = ["*"]
    max_age_seconds = 300
  }
}
