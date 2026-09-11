output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "ec2_security_group_id" {
  value = aws_security_group.ec2.id
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}

output "prometheus_security_group_id" {
  description = "Attach to the private Prometheus/Grafana instance"
  value       = aws_security_group.prometheus.id
}
output "jaeger_security_group_id" {
  value = aws_security_group.jaeger.id
}
