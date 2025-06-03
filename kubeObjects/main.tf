terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "ap-south-1"
}

data "aws_s3_object" "kube_config" {
  bucket = "samplebucketfortesting12345"
  key    = "KubeConfig/kubeconfig"
}

provider "kubernetes" {
  config_path    = data.aws_s3_bucket_object.kube_config.body
  config_context = "cluster_admin_context"
}
