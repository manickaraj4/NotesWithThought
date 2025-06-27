output "vpc_id" {
  value = aws_vpc.kubernetes_vpc.id
}

output "default_route_table_id" {
  value = aws_vpc.kubernetes_vpc.default_route_table_id
}

output "private_route_table_id" {
  value = aws_route_table.private_route_table.id
}

output "internet_gw" {
  value = aws_internet_gateway.internet_gw.id
}

output "public_subnet_1a" {
  value = aws_subnet.public_subnet_1a.id
}

output "public_subnet_1b" {
  value = aws_subnet.public_subnet_1b.id
}

output "public_subnet_1c" {
  value = aws_subnet.public_subnet_1c.id
}

output "private_subnet_1a" {
  value = aws_subnet.private_subnet_1a.id
}

output "private_subnet_1b" {
  value = aws_subnet.private_subnet_1b.id
}

output "private_subnet_1c" {
  value = aws_subnet.private_subnet_1c.id
}
