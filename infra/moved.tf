# Keep these mappings so existing remote state upgrades without recreating resources.

moved {
  from = aws_s3_bucket.images
  to   = module.image_storage.aws_s3_bucket.images
}

moved {
  from = aws_s3_bucket_public_access_block.images
  to   = module.image_storage.aws_s3_bucket_public_access_block.images
}

moved {
  from = aws_s3_bucket_ownership_controls.images
  to   = module.image_storage.aws_s3_bucket_ownership_controls.images
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.images
  to   = module.image_storage.aws_s3_bucket_server_side_encryption_configuration.images
}

moved {
  from = aws_s3_bucket_policy.images
  to   = module.image_storage.aws_s3_bucket_policy.images
}

moved {
  from = aws_iam_user.image_storage
  to   = module.image_storage.aws_iam_user.image_storage
}

moved {
  from = aws_iam_user_policy.image_storage
  to   = module.image_storage.aws_iam_user_policy.image_storage
}

moved {
  from = aws_iam_access_key.image_storage
  to   = module.image_storage.aws_iam_access_key.image_storage
}

moved {
  from = aws_s3_bucket.private_images
  to   = module.image_storage.aws_s3_bucket.private_images
}

moved {
  from = aws_s3_bucket_public_access_block.private_images
  to   = module.image_storage.aws_s3_bucket_public_access_block.private_images
}

moved {
  from = aws_s3_bucket_ownership_controls.private_images
  to   = module.image_storage.aws_s3_bucket_ownership_controls.private_images
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.private_images
  to   = module.image_storage.aws_s3_bucket_server_side_encryption_configuration.private_images
}

moved {
  from = aws_s3_bucket_policy.private_images
  to   = module.image_storage.aws_s3_bucket_policy.private_images
}

moved {
  from = aws_s3_bucket_cors_configuration.private_images
  to   = module.image_storage.aws_s3_bucket_cors_configuration.private_images
}

moved {
  from = aws_iam_user_policy.private_image_storage
  to   = module.image_storage.aws_iam_user_policy.private_image_storage
}

moved {
  from = aws_cloudfront_origin_access_control.images
  to   = module.image_storage.aws_cloudfront_origin_access_control.images
}

moved {
  from = aws_cloudfront_cache_policy.images
  to   = module.image_storage.aws_cloudfront_cache_policy.images
}

moved {
  from = aws_cloudfront_response_headers_policy.images
  to   = module.image_storage.aws_cloudfront_response_headers_policy.images
}

moved {
  from = aws_cloudfront_distribution.images
  to   = module.image_storage.aws_cloudfront_distribution.images
}

moved {
  from = aws_acm_certificate.api
  to   = module.api_domain.aws_acm_certificate.api
}

moved {
  from = aws_route53_record.api_certificate_validation
  to   = module.api_domain.aws_route53_record.api_certificate_validation
}

moved {
  from = aws_acm_certificate_validation.api
  to   = module.api_domain.aws_acm_certificate_validation.api
}

moved {
  from = aws_route53_record.api
  to   = module.api_domain.aws_route53_record.api
}
