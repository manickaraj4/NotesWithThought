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
  value = module.vpce_endpoints.vpce_ssm_dns
}

output "kms_endpoint" {
  value = module.vpce_endpoints.vpce_kms_dns
}

output "ecrdkr_endpoint" {
  value = module.vpce_endpoints.vpce_ecr_dcr_dns
}

output "ecrapi_endpoint" {
  value = module.vpce_endpoints.vpce_ecr_api_dns
}

output "s3_endpoint" {
  value = module.vpce_endpoints.vpce_s3_prefix
}

output "ec2_endpoint" {
  value = module.vpce_endpoints.vpce_ec2_dns
}