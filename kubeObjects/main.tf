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
  region = var.aws_region
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
        "602401143452.dkr.ecr.${var.aws_region}.amazonaws.com" = {
          "username" = "AWS"
          "auth"     = "${data.aws_ecr_authorization_token.ecr_token.authorization_token}"
        }
      }
    })
  }
}

/*
data "aws_s3_object" "kube_client_cert" {
  bucket = var.config_s3_bucket
  key    = "KubeConfig/client-cert.pem"
}

data "aws_s3_object" "kube_client_key" {
  bucket = var.config_s3_bucket
  key    = "KubeConfig/client-key.pem"
}

data "aws_s3_object" "kube_ca_cert" {
  bucket = var.config_s3_bucket
  key    = "KubeConfig/cluster-ca-cert.pem"
}
*/

data "aws_ssm_parameter" "kube_static_token" {
  name            = "kube_static_token"
  with_decryption = true
}

data "aws_ssm_parameter" "lb_name" {
  name            = "lb_name"
  with_decryption = false
}

provider "kubernetes" {
  host     = "https://${data.aws_ssm_parameter.lb_name.value}:8443"
  insecure = true
  token    = data.aws_ssm_parameter.kube_static_token.value
  /*
  client_certificate     = data.aws_s3_object.kube_client_cert.body
  client_key             = data.aws_s3_object.kube_client_key.body
  cluster_ca_certificate = data.aws_s3_object.kube_ca_cert.body
  */
}

module "vpc_cni_deployment" {
  source = "./vpc-cni"
}

module "go_server_deployment" {
  source = "./goserverdeployment"

  aws_region = var.aws_region
}

provider "helm" {
  kubernetes = {
    host     = "https://${data.aws_ssm_parameter.lb_name.value}:8443"
    insecure = true
    token    = data.aws_ssm_parameter.kube_static_token.value
  }

  /*  registries = [
    {
      url      = "oci://private.registry"
      username = "username"
      password = "password"
    }
  ] */
}

resource "kubernetes_namespace" "nginx_ingress_ns" {
  metadata {
    name = "ingress-nginx"
  }
}

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

  set = [
    {
      name  = "clusterName"
      value = "kubernetes"
    }
  ]
}

/* resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  cleanup_on_fail = true
  atomic = true

  set = [
    {
      name  = "service.type"
      value = "ClusterIP"
    }
  ] 
} */

/* resource "kubernetes_manifest" "test-crd" {
  manifest = {
    apiVersion = "elbv2.k8s.aws/v1beta1"
    kind       = "TargetGroupBinding"

    metadata = {
      name = "default-tgb"
    }

    spec = {
      targetGroupName = ""

      serviceRef = {
        name = "posts-app"
        port = "80"
      }
    }
  }
} */



