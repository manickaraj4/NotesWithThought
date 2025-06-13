terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.13.1"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

provider "time" {
}

module "servers" {
  source = "./instances"

  aws_region       = var.aws_region
  config_s3_bucket = var.config_s3_bucket
  lb_sg_id         = module.lb.alb_sg
}

module "lb" {
  source = "./loadbalancers"

  aws_region       = var.aws_region
  config_s3_bucket = var.config_s3_bucket
  master_node      = module.servers.master_node_id
}

module "ecrrepo" {
  source = "./ecr"
}