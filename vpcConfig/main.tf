terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.13.1"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }

  required_version = ">= 1.2.0"
}

provider "http" {
}

provider "aws" {
  region = var.aws_region
}

provider "time" {
}

provider "random" {
}

module "vpc" {
  source = "./vpc"

  aws_region = var.aws_region
}

module "vpce_endpoints" {
  count  = var.deploy_interface_endpoints ? 1 : 0
  source = "./interfaceendpoint"

  aws_region             = var.aws_region
  vpc_id                 = module.vpc.vpc_id
  private_route_table_id = module.vpc.private_route_table_id
  public_subnet_1a       = module.vpc.public_subnet_1a
  public_subnet_1b       = module.vpc.public_subnet_1b
  public_subnet_1c       = module.vpc.public_subnet_1c
}

module "database" {
  source = "./database"

  aws_region       = var.aws_region
  allow_ec2_sg     = module.servers.ec2_common_sg
  private_subnet_a = module.vpc.private_subnet_1a
  private_subnet_b = module.vpc.private_subnet_1b
  private_subnet_c = module.vpc.private_subnet_1c
}

module "servers" {
  depends_on = [module.vpce_endpoints]
  source     = "./instances"

  aws_region       = var.aws_region
  config_s3_bucket = var.config_s3_bucket
  lb_sg_id         = module.lb.alb_sg
  vpc_id           = module.vpc.vpc_id

  # deploy instances on public subnet if interface endpoints are not enabled.
  subnet_1a         = var.deploy_interface_endpoints ? module.vpc.private_subnet_1a : module.vpc.public_subnet_1a
  subnet_1b         = var.deploy_interface_endpoints ? module.vpc.private_subnet_1b : module.vpc.public_subnet_1b
  subnet_1c         = var.deploy_interface_endpoints ? module.vpc.private_subnet_1c : module.vpc.public_subnet_1c
  in_private_subnet = var.deploy_interface_endpoints ? true : false
}

module "lb" {
  source = "./loadbalancers"

  aws_region       = var.aws_region
  config_s3_bucket = var.config_s3_bucket
  master_node      = module.servers.master_node_id
  worker_node      = module.servers.worker_node_id
  vpc_id           = module.vpc.vpc_id
  certid_ssmname   = var.cert_id_ssm_name
  public_subnet_1a = module.vpc.public_subnet_1a
  public_subnet_1b = module.vpc.public_subnet_1b
  public_subnet_1c = module.vpc.public_subnet_1c
}

module "dns_record_update" {
  source = "./dnssetup"

  lb_dns = module.lb.lb_dns
  record = "*"
  domain = var.domain
}

module "ecrrepo" {
  source = "./ecr"
}

