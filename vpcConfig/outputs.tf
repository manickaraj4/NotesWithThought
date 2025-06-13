output "lb_dns" {
  value = module.lb.lb_dns
}

output "master_node_public_address" {
  value = module.servers.master_node_public_address
}

output "worker_node_public_address" {
  value = module.servers.worker_node_public_address
}