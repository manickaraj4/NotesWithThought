variable "aws_region" {
  default = "ap-south-1"
  type    = string
}

variable "ssh_key_pub" {
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGW9uO5m+sTquPQV6CsaQRZ+JhqmAAxArvluSRs5FINQ manickaraj.km@LT8649"
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

variable "serviceaccount_map" {
  type = map(object({
    namespace      = string
    serviceaccount = string
    policyfilename = string
  }))
}
