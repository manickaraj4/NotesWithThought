
output "master_node_public_address" {
  value = aws_instance.master_server.public_dns
}

output "worker_node_public_address" {
  value = aws_instance.worker_node.public_dns
}

output "master_node_id" {
  value = aws_instance.master_server.id
}