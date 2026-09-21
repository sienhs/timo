resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-redis-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.name}-redis-subnet-group"
  }
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name}-redis"
  description          = "Private Redis cache for ${var.name}"

  engine         = "redis"
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = var.port

  num_cache_clusters         = 1
  automatic_failover_enabled = false
  multi_az_enabled           = false

  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [var.security_group_id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.auth_token

  snapshot_retention_limit = 0
  apply_immediately        = true

  tags = {
    Name = "${var.name}-redis"
  }
}
