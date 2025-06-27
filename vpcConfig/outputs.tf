output "lb_dns" {
  value = module.lb.lb_dns
}

output "master_node_private_address" {
  value = module.servers.master_node_private_address
}

output "worker_node_private_address" {
  value = module.servers.worker_node_private_address
}

output "ssm_endpoint" {
  value = var.deploy_interface_endpoints ? module.vpce_endpoints.vpce_ssm_dns : null
}

output "kms_endpoint" {
  value = var.deploy_interface_endpoints ? module.vpce_endpoints.vpce_kms_dns : null
}

output "ecrdkr_endpoint" {
  value = var.deploy_interface_endpoints ? module.vpce_endpoints.vpce_ecr_dcr_dns : null
}

output "ecrapi_endpoint" {
  value = var.deploy_interface_endpoints ? module.vpce_endpoints.vpce_ecr_api_dns : null
}

/* output "s3_endpoint" {
  value = module.vpce_endpoints.vpce_s3_prefix
}

output "ec2_endpoint" {
  value = module.vpce_endpoints.vpce_ec2_dns
} */