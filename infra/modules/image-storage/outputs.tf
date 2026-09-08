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

output "private_image_bucket_name" {
  value = aws_s3_bucket.private_images.id
}

output "image_cdn_url" {
  description = "Append /<S3 object key> to serve a public image over HTTPS"
  value       = "https://${aws_cloudfront_distribution.images.domain_name}"
}

output "image_cdn_distribution_id" {
  value = aws_cloudfront_distribution.images.id
}

output "runtime_environment" {
  description = "Image environment values injected into the backend secret"
  sensitive   = true
  value = {
    AWS_ACCESS_KEY_ID      = aws_iam_access_key.image_storage.id
    AWS_SECRET_ACCESS_KEY  = aws_iam_access_key.image_storage.secret
    AWS_REGION             = var.aws_region
    S3_PUBLIC_BUCKET_NAME  = aws_s3_bucket.images.id
    S3_PRIVATE_BUCKET_NAME = aws_s3_bucket.private_images.id
    IMAGE_BASE_URL         = "https://${aws_cloudfront_distribution.images.domain_name}"
  }
}
