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

data "aws_ecr_authorization_token" "ecr_token" {
}

resource "kubernetes_secret" "docker_token_secret" {
  metadata {
    name      = "docker-cfg"
    namespace = "kube-system"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "602401143452.dkr.ecr.ap-south-1.amazonaws.com" = {
          "username" = "AWS"
          "auth"     = "${data.aws_ecr_authorization_token.ecr_token.authorization_token}"
        }
      }
    })
  }
}

/*
data "aws_s3_object" "kube_client_cert" {
  bucket = "samplebucketfortesting12345"
  key    = "KubeConfig/client-cert.pem"
}

data "aws_s3_object" "kube_client_key" {
  bucket = "samplebucketfortesting12345"
  key    = "KubeConfig/client-key.pem"
}

data "aws_s3_object" "kube_ca_cert" {
  bucket = "samplebucketfortesting12345"
  key    = "KubeConfig/cluster-ca-cert.pem"
}
*/

data "aws_ssm_parameter" "kube_static_token" {
  name            = "kube_static_token"
  with_decryption = true
}


provider "kubernetes" {
  host     = "https://masterlb-753854550.ap-south-1.elb.amazonaws.com:8443"
  insecure = true
  token    = data.aws_ssm_parameter.kube_static_token.value
  /*
  client_certificate     = data.aws_s3_object.kube_client_cert.body
  client_key             = data.aws_s3_object.kube_client_key.body
  cluster_ca_certificate = data.aws_s3_object.kube_ca_cert.body
  */
}


/*
provider "kubernetes" {
  config_path    = "/home/codespace/.kube/config"
}
*/


