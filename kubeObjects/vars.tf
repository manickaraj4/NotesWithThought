variable "apiserver_host" {
  default = "https://masterlb-493481425.ap-south-1.elb.amazonaws.com:8443"
  type = string
}

variable "aws_region" {
  default = "ap-south-1"
  type    = string
}

variable "config_s3_bucket" {
  default = "samplebucketfortesting12345"
  type    = string
}