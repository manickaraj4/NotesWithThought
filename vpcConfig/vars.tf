variable "aws_region" {
  default = "ap-south-1"
  type    = string
}

variable "config_s3_bucket" {
  default = "samplebucketfortesting12345"
  type    = string
}

/*
variable "environment" {
  default = "default"
  type        = string
}

variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  description = "CIDR block of the vpc"
}

variable "public_subnets_cidr" {
  type        = list(any)
  default     = ["10.0.0.0/20", "10.0.128.0/20"]
  description = "CIDR block for Public Subnet"
}

variable "private_subnets_cidr" {
  type        = list(any)
  default     = ["10.0.16.0/20", "10.0.144.0/20"]
  description = "CIDR block for Private Subnet"
}
*/
