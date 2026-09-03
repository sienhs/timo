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

  name     = "${var.project_name}-${var.environment}"
  vpc_id   = module.network.vpc_id
  app_port = var.app_port
}

module "ec2" {
  source = "./modules/ec2"

  name              = "${var.project_name}-${var.environment}"
  subnet_id         = module.network.private_app_subnet_id
  security_group_id = module.security.ec2_security_group_id
  instance_type     = var.ec2_instance_type
  app_port          = var.app_port

  # Ensure the private subnet has an Internet route through the NAT instance
  # before application EC2 user_data attempts dnf update/install.
  depends_on = [module.nat_instance]
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

module "alb" {
  source = "./modules/alb"

  name               = "${var.project_name}-${var.environment}"
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  security_group_id  = module.security.alb_security_group_id
  target_instance_id = module.ec2.instance_id
  app_port           = var.app_port
  health_check_path  = var.health_check_path
}
