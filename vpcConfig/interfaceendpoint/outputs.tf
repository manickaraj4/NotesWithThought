output "vpce_ssm_dns" {
  value = aws_vpc_endpoint.ssm_private_endpoint.dns_entry[0]["dns_name"]
}

output "vpce_kms_dns" {
  value = aws_vpc_endpoint.kms_private_endpoint.dns_entry[0]["dns_name"]
}

output "vpce_ecr_dcr_dns" {
  value = aws_vpc_endpoint.ecr_dcr_private_endpoint.dns_entry[0]["dns_name"]
}

output "vpce_ecr_api_dns" {
  value = aws_vpc_endpoint.ecr_api_private_endpoint.dns_entry[0]["dns_name"]
}

output "vpce_s3_prefix" {
  value = aws_vpc_endpoint.s3_private_endpoint.prefix_list_id
}

output "vpce_ec2_dns" {
  value = aws_vpc_endpoint.ec2_private_endpoint.dns_entry[0]["dns_name"]
}