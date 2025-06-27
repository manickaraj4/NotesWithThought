variable "aws_region" {
  default = "ap-south-1"
  type    = string
}

variable "config_s3_bucket" {
  default = "samplebucketfortesting12345"
  type    = string
}

variable "cert_id_ssm_name" {
  default = "DomainCertId"
  type    = string
}

variable "domain" {
  default = "manicks.xyz"
  type    = string
}

variable "deploy_interface_endpoints" {
  default = false
  type    = bool
}
