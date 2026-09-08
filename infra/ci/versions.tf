terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.62"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }

  backend "s3" {
    bucket       = "timo-terraform-state-023433588174-ap-northeast-2-an"
    key          = "ci/prod/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}

# Independent root: terraform -chdir=infra/ci init/plan/apply.
# This does not create or change the application VPC, EC2, or RDS.
# State is stored in the dedicated S3 backend above.
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project   = "timo"
      Component = "gitlab-ci"
      ManagedBy = "Terraform"
    }
  }
}
