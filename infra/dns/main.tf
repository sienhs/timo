terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.62"
    }
  }

  backend "s3" {
    bucket       = "timo-terraform-state-023433588174-ap-northeast-2-an"
    key          = "dns/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project   = "ticketing"
      ManagedBy = "Terraform"
    }
  }
}

variable "domain_name" {
  description = "Registered domain name, without a scheme, path, or trailing dot"
  type        = string

  validation {
    condition     = length(var.domain_name) <= 253 && can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.domain_name))
    error_message = "Provide a lowercase domain such as example.com, without https:// or a trailing dot."
  }
}

resource "aws_route53_zone" "domain" {
  name          = var.domain_name
  comment       = "Public DNS for ${var.domain_name}; domain registered at Gabia"
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "network" {
  zone_id = aws_route53_zone.domain.zone_id
  name    = "network.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = ["43.202.55.114"]
}

output "zone_id" {
  description = "Hosted zone ID for subsequent DNS records"
  value       = aws_route53_zone.domain.zone_id
}

output "domain_name" {
  value = aws_route53_zone.domain.name
}

output "name_servers" {
  description = "Set all four values as the domain's name servers at Gabia"
  value       = aws_route53_zone.domain.name_servers
}
