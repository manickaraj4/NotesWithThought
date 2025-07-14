variable "aws_region" {
  default = "ap-south-1"
  type    = string
}

variable "bucket" {
  type = string
}

variable "domain" {
  default = "manicks.xyz"
  type    = string
}

variable "namespace" {
  type = string
}

variable "serviceaccount" {
  type = string
}

variable "policyfilename" {
  type = string
}
