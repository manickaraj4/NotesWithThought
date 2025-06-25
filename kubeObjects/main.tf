terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_ecr_authorization_token" "ecr_token" {
}

/* resource "kubernetes_secret" "docker_token_secret" {
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
} */

resource "kubernetes_secret" "docker_token_secret_current_account" {
  metadata {
    name      = "docker-cfg-current-account"
    namespace = "kube-system"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com" = {
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
  host     = "https://${data.aws_ssm_parameter.lb_name.value}:6443"
  insecure = true
  token    = data.aws_ssm_parameter.kube_static_token.value
  /*
  client_certificate     = data.aws_s3_object.kube_client_cert.body
  client_key             = data.aws_s3_object.kube_client_key.body
  cluster_ca_certificate = data.aws_s3_object.kube_ca_cert.body
  */
}

/* module "vpc_cni_deployment" {
  source = "./vpc-cni"
} */

provider "helm" {
  kubernetes = {
    host     = "https://${data.aws_ssm_parameter.lb_name.value}:6443"
    insecure = true
    token    = data.aws_ssm_parameter.kube_static_token.value
  }
}

# ditching VPC and moved to flannel
/* resource "helm_release" "aws_vpc_cni" {
  name            = "aws-vpc-cni"
  repository      = "https://aws.github.io/eks-charts"
  chart           = "aws-vpc-cni"
  namespace       = "kube-system"
  cleanup_on_fail = true
  atomic          = true

  values = [
    yamlencode(yamldecode(templatefile("${path.module}/vpc-cni/charts/values.yaml", { region = "${var.aws_region}" })))
  ]
} */

# Flannel CNI plugin
resource "helm_release" "flannel_cni" {
  name            = "flannel"
  repository      = "https://flannel-io.github.io/flannel"
  chart           = "flannel"
  namespace       = "kube-system"
  cleanup_on_fail = true
  atomic          = true

  set = [
    /*     {
      name  = "flannel.backend"
      value = "host-gw"
    }, */
    {
      name  = "flannel.image.repository"
      value = "docker.io/flannel/flannel"
    },
    {
      name  = "flannel.image_cni.repository"
      value = "docker.io/flannel/flannel-cni-plugin"
    }
  ]
}

module "go_server_deployment" {
  depends_on = [helm_release.flannel_cni]
  source     = "./goserverdeployment"

  domain     = var.domain
  aws_region = var.aws_region
}

/* resource "kubernetes_namespace" "nginx_ingress_ns" {
  metadata {
    name = "ingress-nginx"
  }
} */

/* resource "helm_release" "aws_lb_controller" {
  depends_on = [helm_release.aws_vpc_cni]
  name            = "aws-load-balancer-controller"
  repository      = "https://aws.github.io/eks-charts"
  chart           = "aws-load-balancer-controller"
  cleanup_on_fail = true
  atomic          = true
  namespace       = "kube-system"

  values = [
    yamlencode(yamldecode(templatefile("${path.module}/awsloadbalancercontroller/charts/values.yaml", { region = "${var.aws_region}", repo = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/ecr-public/eks/aws-load-balancer-controller", tag = "v2.13.3", imagepullsecrets = "docker-cfg-current-account" })))
  ]
} */

resource "helm_release" "nginx_ingress" {
  name            = "ingress-nginx"
  repository      = "https://kubernetes.github.io/ingress-nginx"
  chart           = "ingress-nginx"
  cleanup_on_fail = true
  atomic          = true

  set = [
    {
      name  = "controller.service.type"
      value = "NodePort"
    },
    {
      name  = "controller.kind"
      value = "DaemonSet"
    },
    {
      name  = "controller.service.nodePorts.http"
      value = "30007"
    },
    {
      name  = "controller.service.nodePorts.https"
      value = "30008"
    }
  ]
}

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



