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


resource "aws_iam_user_policy" "private_image_storage" {
  name = "private-image-bucket-access"
  user = aws_iam_user.image_storage.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:ListBucketMultipartUploads"]
        Resource = aws_s3_bucket.private_images.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
          "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"
        ]
        Resource = "${aws_s3_bucket.private_images.arn}/*"
      }
    ]
  })
}
