output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = module.alb.dns_name
}

output "ec2_instance_id" {
  description = "Application EC2 instance ID"
  value       = module.ec2.instance_id
}

output "ec2_private_ip" {
  description = "Application EC2 private IP"
  value       = module.ec2.private_ip
}

output "nat_instance_id" {
  description = "NAT EC2 instance ID"
  value       = module.nat_instance.instance_id
}

output "nat_public_ip" {
  description = "Elastic IP attached to the NAT instance"
  value       = module.nat_instance.public_ip
}

output "rds_endpoint" {
  description = "MySQL endpoint"
  value       = module.rds.endpoint
}

output "rds_port" {
  description = "MySQL port"
  value       = module.rds.port
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "backend_ecr_repository_url" {
  description = "Repository URL for pushing and pulling backend container images"
  value       = module.ecr.repository_url
}

output "backend_ecr_repository_arn" {
  description = "Backend ECR repository ARN for IAM policies"
  value       = module.ecr.arn
}

output "backend_source_bucket_name" {
  description = "Temporary GitLab source bundles for the backend image build"
  value       = module.backend_cicd.source_bucket_name
}

output "backend_codebuild_project_name" {
  description = "CodeBuild project that builds and pushes backend Docker images"
  value       = module.backend_cicd.codebuild_project_name
}

output "backend_gitlab_ci_role_arn" {
  description = "GitLab OIDC role used to upload source bundles, start CodeBuild, and deploy through SSM"
  value       = module.backend_cicd.gitlab_ci_role_arn
}

output "backend_runtime_secret_arn" {
  description = "Secrets Manager secret automatically loaded by the EC2 deployment script"
  value       = module.backend_secret.arn
}
