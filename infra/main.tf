module "ecr" {
  source = "./modules/ecr"

  name = "${var.project_name}-${var.environment}-backend"
}

module "backend_secret" {
  source = "./modules/secrets-manager"

  name = "${var.project_name}/${var.environment}/backend"
  secret_string = jsonencode(merge({
    SPRING_PROFILES_ACTIVE               = "prod"
    DB_URL                               = "jdbc:mysql://${module.rds.endpoint}:${module.rds.port}/${var.db_name}?connectionTimeZone=Asia/Seoul&characterEncoding=UTF-8"
    DB_USERNAME                          = var.db_username
    DB_PASSWORD                          = var.db_password
    JWT_SECRET                           = var.jwt_secret
    ENTRY_PASS_SECRET                    = var.entry_pass_secret
    ADMIN_PRIVATE_KEY                    = var.admin_private_key
    WALLET_MASTER_KEY                    = var.wallet_master_key
    REDIS_HOST                           = module.redis.primary_endpoint_address
    REDIS_PORT                           = tostring(module.redis.port)
    REDIS_PASSWORD                       = var.redis_auth_token
    FIREBASE_MESSAGING_ENABLED           = "true"
    PUSH_CHANNEL_GENERAL                 = "timo_general_notifications"
    FIREBASE_SERVICE_ACCOUNT_JSON_BASE64 = var.firebase_service_account_json_base64
    SEED_ORGANIZER_PHONE                 = var.seed_organizer_phone
    SEED_ORGANIZER_NAME                  = var.seed_organizer_name
    SEED_ORGANIZER_NICKNAME              = var.seed_organizer_nickname
    SEED_ADMIN_PHONE                     = var.seed_admin_phone
    SEED_ADMIN_NAME                      = var.seed_admin_name
    SEED_ADMIN_NICKNAME                  = var.seed_admin_nickname
    SEED_ADMIN_USERNAME                  = var.seed_admin_username
    SEED_ADMIN_PASSWORD                  = var.seed_admin_password
  }, var.solapi_environment, module.image_storage.runtime_environment))
}

module "backend_cicd" {
  source = "./modules/backend-cicd"

  name                = "${var.project_name}-${var.environment}"
  aws_region          = var.aws_region
  ecr_repository_arn  = module.ecr.arn
  ecr_repository_url  = module.ecr.repository_url
  ec2_instance_id     = module.ec2.instance_id
  gitlab_url          = "https://lab.ssafy.com"
  gitlab_project_path = var.gitlab_project_path
}

module "network" {
  source = "./modules/network"

  name         = "${var.project_name}-${var.environment}"
  vpc_cidr     = var.vpc_cidr
  primary_az   = var.primary_az
  secondary_az = var.secondary_az
}

module "nat_instance" {
  source = "./modules/nat-instance"

  name                    = "${var.project_name}-${var.environment}"
  vpc_id                  = module.network.vpc_id
  public_subnet_id        = module.network.public_primary_subnet_id
  private_route_table_id  = module.network.private_app_route_table_id
  private_app_subnet_cidr = module.network.private_app_subnet_cidr
  instance_type           = var.nat_instance_type

  # NAT user_data installs packages from the Internet during first boot,
  # so wait until the public route/association in the network module exists.
  depends_on = [module.network]
}

module "security" {
  source = "./modules/security"

  name       = "${var.project_name}-${var.environment}"
  vpc_id     = module.network.vpc_id
  app_port   = var.app_port
  redis_port = var.redis_port
}

module "redis" {
  source = "./modules/redis"

  name              = "${var.project_name}-${var.environment}"
  subnet_ids        = module.network.db_subnet_ids
  security_group_id = module.security.redis_security_group_id
  node_type         = var.redis_node_type
  engine_version    = var.redis_engine_version
  port              = var.redis_port
  auth_token        = var.redis_auth_token
}

module "ec2" {
  source = "./modules/ec2"

  name                 = "${var.project_name}-${var.environment}"
  subnet_id            = module.network.private_app_subnet_id
  security_group_id    = module.security.ec2_security_group_id
  instance_type        = var.ec2_instance_type
  root_volume_size     = var.ec2_root_volume_size
  app_port             = var.app_port
  aws_region           = var.aws_region
  backend_secret_arn   = module.backend_secret.arn
  db_endpoint          = module.rds.endpoint
  db_port              = module.rds.port
  db_name              = var.db_name
  db_schema_sql_base64 = base64encode(file("${path.module}/bootstrap/init.sql"))
  detailed_monitoring  = var.ec2_detailed_monitoring

  # Ensure the private subnet has an Internet route through the NAT instance
  # before application EC2 user_data attempts dnf update/install.
  depends_on = [module.nat_instance, module.rds]
}

module "rds" {
  source = "./modules/rds"

  name              = "${var.project_name}-${var.environment}"
  db_subnet_ids     = module.network.db_subnet_ids
  security_group_id = module.security.rds_security_group_id
  availability_zone = var.primary_az
  instance_class    = var.db_instance_class
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
}

module "grafana_domain" {
  source = "./modules/api-domain"

  domain_name  = var.domain_name
  subdomain    = var.grafana_subdomain
  alb_dns_name = module.alb.dns_name
  alb_zone_id  = module.alb.zone_id
}

module "alb" {
  source = "./modules/alb"

  name                    = "${var.project_name}-${var.environment}"
  vpc_id                  = module.network.vpc_id
  public_subnet_ids       = module.network.public_subnet_ids
  security_group_id       = module.security.alb_security_group_id
  target_instance_id      = module.ec2.instance_id
  app_port                = var.app_port
  health_check_path       = var.health_check_path
  certificate_arn         = module.api_domain.certificate_arn
  monitoring_instance_id  = module.monitoring.instance_id
  grafana_certificate_arn = module.grafana_domain.certificate_arn
  grafana_host_name       = "${var.grafana_subdomain}.${var.domain_name}"
}

module "image_storage" {
  source = "./modules/image-storage"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
}

module "api_domain" {
  source = "./modules/api-domain"

  domain_name  = var.domain_name
  alb_dns_name = module.alb.dns_name
  alb_zone_id  = module.alb.zone_id
}

module "monitoring" {
  source = "./modules/monitoring"

  name                     = "${var.project_name}-${var.environment}"
  subnet_id                = module.network.private_app_subnet_id
  security_group_id        = module.security.prometheus_security_group_id
  jaeger_security_group_id = module.security.jaeger_security_group_id
  instance_type            = var.monitoring_instance_type
  root_volume_size         = var.monitoring_root_volume_size
  aws_region               = var.aws_region
  application_private_ip   = module.ec2.private_ip
  application_instance_id  = module.ec2.instance_id
  rds_instance_identifier  = module.rds.identifier
  grafana_admin_password   = var.grafana_admin_password
  grafana_domain           = "${var.grafana_subdomain}.${var.domain_name}"

  depends_on = [module.nat_instance]
}

resource "aws_ssm_parameter" "tracing_endpoint" {
  name  = "/${var.project_name}-${var.environment}/tracing/endpoint"
  type  = "String"
  value = "http://${module.monitoring.private_ip}:4318/v1/traces"
}

resource "aws_cloudwatch_dashboard" "operations" {
  dashboard_name = "${var.project_name}-${var.environment}-operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "EC2 - CPU and host memory"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", module.ec2.instance_id, { label = "CPU (%)" }],
            ["Timo/EC2", "mem_used_percent", "InstanceId", module.ec2.instance_id, { label = "Memory (%)" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "EC2 - disk and network"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            ["Timo/EC2", "disk_used_percent", "InstanceId", module.ec2.instance_id, { label = "Disk used (%)" }],
            ["AWS/EC2", "NetworkIn", "InstanceId", module.ec2.instance_id, { label = "Network received" }],
            ["AWS/EC2", "NetworkOut", "InstanceId", module.ec2.instance_id, { label = "Network sent" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "RDS - CPU, connections, and free storage"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", module.rds.identifier, { label = "CPU (%)" }],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", module.rds.identifier, { label = "Connections" }],
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", module.rds.identifier, { label = "Free storage (bytes)" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "RDS - read/write latency and IOPS"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", module.rds.identifier, { label = "Read latency" }],
            ["AWS/RDS", "WriteLatency", "DBInstanceIdentifier", module.rds.identifier, { label = "Write latency" }],
            ["AWS/RDS", "ReadIOPS", "DBInstanceIdentifier", module.rds.identifier, { label = "Read IOPS" }],
            ["AWS/RDS", "WriteIOPS", "DBInstanceIdentifier", module.rds.identifier, { label = "Write IOPS" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Redis - engine CPU, connections, and free memory"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/ElastiCache", "EngineCPUUtilization", "CacheClusterId", "${module.redis.replication_group_id}-001", { label = "Engine CPU (%)" }],
            ["AWS/ElastiCache", "CurrConnections", "CacheClusterId", "${module.redis.replication_group_id}-001", { label = "Connections" }],
            ["AWS/ElastiCache", "FreeableMemory", "CacheClusterId", "${module.redis.replication_group_id}-001", { label = "Free memory (bytes)" }]
          ]
        }
      }
    ]
  })
}
