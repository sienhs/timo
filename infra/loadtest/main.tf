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
variable "public_subnet_ids" { type = list(string) }
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
variable "db_instance_class" { default = "db.t4g.medium" }
variable "app_instance_count" {
  type    = number
  default = 6
  validation {
    condition     = var.app_instance_count >= 1 && var.app_instance_count <= 32
    error_message = "app_instance_count must be between 1 and 32."
  }
}
variable "app_instance_type" {
  type = string
  validation {
    condition     = var.app_instance_type == "c7i.xlarge"
    error_message = "The load-test topology uses c7i.xlarge (4 vCPU) instances."
  }
  default = "c7i.xlarge"
}
variable "db_password" {
  type      = string
  sensitive = true
  validation {
    condition     = length(var.db_password) >= 8 && length(var.db_password) <= 41 && can(regex("^[a-zA-Z0-9_-]+$", var.db_password))
    error_message = "Use a new test-only password: 8..41 ASCII letters, digits, underscore or hyphen."
  }
}
variable "redis_auth_token" {
  type      = string
  sensitive = true
}
variable "waiting_queue_active_limit" {
  type    = number
  default = 50
}
data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
data "aws_subnet" "app" {
  id = var.public_subnet_ids[0]
}
resource "aws_security_group" "alb" {
  name_prefix = "timo-loadtest-alb-"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
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
resource "aws_security_group" "app" {
  name_prefix = "timo-loadtest-app-"
  vpc_id      = var.vpc_id
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
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
resource "aws_security_group" "redis" {
  name_prefix = "timo-loadtest-redis-"
  vpc_id      = var.vpc_id
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
}
resource "aws_elasticache_subnet_group" "test" {
  name       = "timo-loadtest-redis-subnet-group"
  subnet_ids = var.db_subnet_ids
}
resource "aws_elasticache_replication_group" "test" {
  replication_group_id       = "timo-loadtest-redis"
  description                = "Disposable Redis for queue load tests"
  engine                     = "redis"
  engine_version             = "7.1"
  node_type                  = "cache.t4g.micro"
  num_cache_clusters         = 1
  automatic_failover_enabled = false
  subnet_group_name          = aws_elasticache_subnet_group.test.name
  security_group_ids         = [aws_security_group.redis.id]
  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  auth_token                 = var.redis_auth_token
  snapshot_retention_limit   = 0
  apply_immediately          = true
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
  depends_on = [
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy_attachment.ecr,
  ]
  for_each                    = toset([for index in range(var.app_instance_count) : tostring(index)])
  ami                         = data.aws_ssm_parameter.ami.value
  instance_type               = var.app_instance_type
  subnet_id                   = element(var.public_subnet_ids, tonumber(each.key) % length(var.public_subnet_ids))
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.host.name
  monitoring                  = true
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }
  metadata_options { http_tokens = "required" }
  user_data = "#!/bin/bash\nset -eu\n# AL2023 already includes SSM Agent. Register it before package installation so\n# a transient repository delay cannot make the host invisible to the runner.\nsystemctl enable --now amazon-ssm-agent || true\ndnf install -y amazon-ssm-agent docker mariadb105\nsystemctl enable --now amazon-ssm-agent docker\n"
  tags      = { Name = "timo-loadtest-app-${each.key}" }
}
resource "aws_lb" "app" {
  name               = "timo-loadtest-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
}
resource "aws_lb_target_group" "app" {
  name     = "timo-loadtest-app"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path                = "/actuator/health"
    matcher             = "200-399"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}
resource "aws_lb_target_group_attachment" "app" {
  for_each         = aws_instance.host
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = each.value.id
  port             = 8080
}
resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
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
    region             = var.region
    app_ids            = [for instance in aws_instance.host : instance.id]
    app_instance_count = var.app_instance_count
    app_instance_type  = var.app_instance_type
    base_url           = "http://${aws_lb.app.dns_name}"
    db_host            = aws_db_instance.test.address
    db_id              = aws_db_instance.test.identifier
    target_group_arn   = aws_lb_target_group.app.arn
    image              = var.image
    db_class           = var.db_instance_class
    db_engine          = var.db_engine_version
    redis_host         = aws_elasticache_replication_group.test.primary_endpoint_address
    redis_port         = aws_elasticache_replication_group.test.port
    redis_cluster_id   = one(aws_elasticache_replication_group.test.member_clusters)
    queue_active_limit = var.waiting_queue_active_limit
  }
}
