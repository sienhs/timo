output "primary_endpoint_address" {
  description = "Private primary endpoint hostname for Redis clients."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "port" {
  value = aws_elasticache_replication_group.this.port
}

output "replication_group_id" {
  value = aws_elasticache_replication_group.this.replication_group_id
}
