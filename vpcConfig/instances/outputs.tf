
output "master_node_private_address" {
  value = aws_instance.master_server.private_ip
}

output "worker_node_private_address" {
  value = aws_instance.worker_node.private_ip
}

output "master_node_id" {
  value = aws_instance.master_server.id
}

output "worker_node_id" {
  value = aws_instance.worker_node.id
}