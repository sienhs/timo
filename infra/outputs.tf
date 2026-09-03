output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = module.alb.dns_name
}

output "ec2_instance_id" {
  description = "Application EC2 instance ID"
  value       = module.ec2.instance_id
}

output "ec2_private_ip" {
  description = "Application EC2 private IP"
  value       = module.ec2.private_ip
}

output "nat_instance_id" {
  description = "NAT EC2 instance ID"
  value       = module.nat_instance.instance_id
}

output "nat_public_ip" {
  description = "Elastic IP attached to the NAT instance"
  value       = module.nat_instance.public_ip
}

output "rds_endpoint" {
  description = "MySQL endpoint"
  value       = module.rds.endpoint
}

output "rds_port" {
  description = "MySQL port"
  value       = module.rds.port
}

output "vpc_id" {
  value = module.network.vpc_id
}
