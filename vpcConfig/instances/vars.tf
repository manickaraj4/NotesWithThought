variable "ssh_key_pub" {
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGW9uO5m+sTquPQV6CsaQRZ+JhqmAAxArvluSRs5FINQ manickaraj.km@LT8649"
  type    = string
}

variable "ami" {
  default = "ami-00b7ea845217da02c" # Using Amazon Linux 2 
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

variable "vpc_id" {
  type = string
}

variable "subnet_1a" {
  type = string
}

variable "subnet_1b" {
  type = string
}

variable "subnet_1c" {
  type = string
}

variable "in_private_subnet" {
  type = bool
}

