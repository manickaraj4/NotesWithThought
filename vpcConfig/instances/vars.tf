variable "ssh_key_pub" {
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGW9uO5m+sTquPQV6CsaQRZ+JhqmAAxArvluSRs5FINQ manickaraj.km@LT8649"
  type    = string
}

variable "ami" {
  default = "ami-0f535a71b34f2d44a"
  type    = string
}

variable "instance_type" {
  default = "t3.small"
  type    = string
}

variable "aws_region" {
  type = string
}

variable "config_s3_bucket" {
  type = string
}

variable "lb_sg_id" {
  type = string
}


