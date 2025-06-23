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

module "vpc" {
  source = "./vpc"

  aws_region = var.aws_region
}

module "vpce_endpoints" {
  source = "./interfaceendpoint"

  aws_region             = var.aws_region
  vpc_id                 = module.vpc.vpc_id
  private_route_table_id = module.vpc.private_route_table_id
  public_subnet_1a       = module.vpc.public_subnet_1a
  public_subnet_1b       = module.vpc.public_subnet_1b
  public_subnet_1c       = module.vpc.public_subnet_1c
}

module "servers" {
  depends_on = [module.vpce_endpoints]
  source     = "./instances"

  aws_region        = var.aws_region
  config_s3_bucket  = var.config_s3_bucket
  lb_sg_id          = module.lb.alb_sg
  vpc_id            = module.vpc.vpc_id
  private_subnet_1a = module.vpc.private_subnet_1a
  private_subnet_1b = module.vpc.private_subnet_1b
  private_subnet_1c = module.vpc.private_subnet_1c
}

module "lb" {
  source = "./loadbalancers"

  aws_region       = var.aws_region
  config_s3_bucket = var.config_s3_bucket
  master_node      = module.servers.master_node_id
  vpc_id           = module.vpc.vpc_id
  certid_ssmname   = var.cert_id_ssm_name
  public_subnet_1a = module.vpc.public_subnet_1a
  public_subnet_1b = module.vpc.public_subnet_1b
  public_subnet_1c = module.vpc.public_subnet_1c
}

module "ecrrepo" {
  source = "./ecr"
}

