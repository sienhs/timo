resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = {
    Name = "${var.name}-db-subnet-group"
  }
}

resource "aws_db_instance" "this" {
  identifier = "${var.name}-mysql"

  engine         = "mysql"
  instance_class = var.instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  #manage_master_user_password = false

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  availability_zone      = var.availability_zone

  multi_az            = false
  publicly_accessible = false

  backup_retention_period = 0
  deletion_protection      = false
  skip_final_snapshot      = true

  auto_minor_version_upgrade = true
  apply_immediately           = true

  tags = {
    Name = "${var.name}-mysql"
  }
}
