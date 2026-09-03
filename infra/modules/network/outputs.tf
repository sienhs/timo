output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = [
    aws_subnet.public_primary.id,
    aws_subnet.public_secondary.id
  ]
}

output "public_primary_subnet_id" {
  value = aws_subnet.public_primary.id
}

output "private_app_subnet_id" {
  value = aws_subnet.private_app.id
}

output "private_app_subnet_cidr" {
  value = aws_subnet.private_app.cidr_block
}

output "private_app_route_table_id" {
  value = aws_route_table.private_app.id
}

output "db_subnet_ids" {
  value = [
    aws_subnet.db_primary.id,
    aws_subnet.db_secondary.id
  ]
}
