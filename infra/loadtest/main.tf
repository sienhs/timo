terraform {
  required_version = ">= 1.8.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.62" }
  }
  # Deliberately independent local state. Never use the production backend.
}
provider "aws" {
  region = var.region
  default_tags { tags = { Project = "timo", Environment = "loadtest", ManagedBy = "Terraform" } }
}
variable "region" { default = "ap-northeast-2" }
variable "vpc_id" { type = string }
variable "public_subnet_id" { type = string }
variable "db_subnet_ids" { type = list(string) }
variable "load_generator_cidr" {
  description = "Local computer's public IPv4 address, restricted to /32"
  type        = string
  validation {
    condition     = can(cidrnetmask(var.load_generator_cidr)) && endswith(var.load_generator_cidr, "/32")
    error_message = "Specify your public IPv4 address with /32."
  }
}
variable "image" {
  type = string
  validation {
    condition     = can(regex("@sha256:[a-f0-9]{64}$", var.image))
    error_message = "Use the deployed ECR image pinned by digest."
  }
}
variable "db_engine_version" { type = string }
variable "db_instance_class" { default = "db.t4g.micro" }
variable "cpu_credits" {
  type = string
  validation {
    condition     = contains(["standard", "unlimited"], var.cpu_credits)
    error_message = "Specify the actual production credit mode."
  }
}
variable "db_password" {
  type      = string
  sensitive = true
  validation {
    condition     = length(var.db_password) >= 8 && length(var.db_password) <= 41 && can(regex("^[a-zA-Z0-9_-]+$", var.db_password))
    error_message = "Use a new test-only password: 8..41 ASCII letters, digits, underscore or hyphen."
  }
}
data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
data "aws_subnet" "app" {
  id = var.public_subnet_id
}
resource "aws_security_group" "app" {
  name_prefix = "timo-loadtest-app-"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.load_generator_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "db" {
  name_prefix = "timo-loadtest-db-"
  vpc_id      = var.vpc_id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
}
resource "aws_iam_role" "host" {
  name_prefix        = "timo-loadtest-"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_iam_instance_profile" "host" {
  name_prefix = "timo-loadtest-"
  role        = aws_iam_role.host.name
}
resource "aws_instance" "host" {
  for_each                    = { app = "t3.medium" }
  ami                         = data.aws_ssm_parameter.ami.value
  instance_type               = each.value
  subnet_id                   = var.public_subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.host.name
  monitoring                  = true
  dynamic "credit_specification" {
    for_each = each.key == "app" ? [1] : []
    content { cpu_credits = var.cpu_credits }
  }
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }
  metadata_options { http_tokens = "required" }
  user_data = "#!/bin/bash\nset -eu\ndnf install -y docker mariadb105\nsystemctl enable --now docker\n"
  tags      = { Name = "timo-loadtest-${each.key}" }
}
resource "aws_db_subnet_group" "test" {
  name_prefix = "timo-loadtest-"
  subnet_ids  = var.db_subnet_ids
}
resource "aws_db_instance" "test" {
  availability_zone       = data.aws_subnet.app.availability_zone
  identifier_prefix       = "timo-loadtest-"
  engine                  = "mysql"
  engine_version          = var.db_engine_version
  instance_class          = var.db_instance_class
  allocated_storage       = 20
  storage_type            = "gp3"
  storage_encrypted       = true
  db_name                 = "timo_loadtest"
  username                = "loadtest"
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.test.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
}
output "test" {
  value = {
    region      = var.region
    app_id      = aws_instance.host["app"].id
    base_url    = "http://${aws_instance.host["app"].public_ip}:8080"
    db_host     = aws_db_instance.test.address
    db_id       = aws_db_instance.test.id
    image       = var.image
    cpu_credits = var.cpu_credits
    db_class    = var.db_instance_class
    db_engine   = var.db_engine_version
  }
}
