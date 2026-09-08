output "source_bucket_name" {
  value = aws_s3_bucket.source.bucket
}

output "codebuild_project_name" {
  value = aws_codebuild_project.builder.name
}

output "gitlab_ci_role_arn" {
  value = aws_iam_role.gitlab_ci.arn
}
