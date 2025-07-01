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

/* module "go_server_deployment" {
  depends_on = [helm_release.flannel_cni]
  source     = "./goserverdeployment"

  domain     = var.domain
  aws_region = var.aws_region
} */

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



resource "helm_release" "aws_ebs_csi_driver" {
  depends_on = [helm_release.flannel_cni]
  name            = "aws-ebs-csi-driver"
  repository      = "oci://ghcr.io/deliveryhero/helm-charts"
  chart           = "aws-ebs-csi-driver"
  cleanup_on_fail = true
  atomic          = true
  namespace       = "kube-system"

/*   values = [
    yamlencode(yamldecode(templatefile("${path.module}/awsloadbalancercontroller/charts/values.yaml", { region = "${var.aws_region}", repo = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/ecr-public/eks/aws-load-balancer-controller", tag = "v2.13.3", imagepullsecrets = "docker-cfg-current-account" })))
  ] */
}

resource "helm_release" "jenkins_deployment" {
  depends_on      = [helm_release.flannel_cni, helm_release.aws_ebs_csi_driver, helm_release.nginx_ingress, kubernetes_storage_class_v1.ebs_storage_class]
  name            = "jenkins"
  repository      = "https://charts.jenkins.io"
  chart           = "jenkins"
  cleanup_on_fail = true
  atomic          = true
  namespace       = "kube-system"

  set = [
    {
      name  = "controller.admin.createSecret"
      value = true
    },
    {
      name  = "controller.ingress.enabled"
      value = true
    },
    {
      name  = "controller.ingress.ingressClassName"
      value = "nginx"
    },
    {
      name  = "controller.ingress.hostName"
      value = "jenkins.${var.domain}"
    },
    {
      name  = "controller.nodeSelector.kubernetes\\.io\\/arch"
      value = "arm64"
    },
/*     {
      name  = "controller.affinity"
      value = yamlencode(yamldecode(file("${path.module}/jenkinsdeploy/affinityselector.yaml")))
    }, */
    {
      name  = "persistence.enabled"
      value = true
    },
    {
      name  = "persistence.storageClass"
      value = "ebs-sc"
    }
  ]

/*   values = [
    yamlencode(yamldecode(templatefile("${path.module}/jenkinsdeploy/charts/values.yaml", { domain = "jenkins.${var.domain}"})))
  ]  */
}

resource "helm_release" "nginx_ingress" {
  depends_on      = [helm_release.flannel_cni]
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

resource "kubernetes_storage_class_v1" "ebs_storage_class" {
  depends_on    = [helm_release.aws_ebs_csi_driver]
  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"

  metadata {
    name = "ebs-sc"
  }
}

/*
resource "helm_release" "keycloak_chart" {
  depends_on      = [helm_release.nginx_ingress, helm_release.aws_ebs_csi_driver, kubernetes_storage_class_v1.ebs_storage_class]
  name            = "keycloak"
  repository      = "oci://registry-1.docker.io/"
  chart           = "bitnamicharts/keycloak"
  cleanup_on_fail = true
  atomic          = true

  set = [
    {
      name  = "auth.adminUser"
      value = "admin"
    },
    {
      name  = "auth.adminPassword"
      value = "nginxbasedauth"
    },
    {
      name  = "ingress.enabled"
      value = true
    },
    {
      name  = "tls.enabled"
      value = true
    },
    {
      name  = "tls.autoGenerated"
      value = true
    },
    {
      name  = "ingress.tls"
      value = true
    },
        {
      name  = "ingress.selfSigned"
      value = true
    },
    {
      name  = "ingress.ingressClassName"
      value = "nginx"
    },
    {
      name  = "ingress.hostname"
      value = "keycloak.${var.domain}"
    },
    {
      name  = "postgresql.enabled"
      value = true
    },
    {
      name  = "postgresql.global.storageClass"
      value = "ebs-sc"
    }
  ]
} 
*/

/*
resource "helm_release" "dex_chart" {
  depends_on      = [helm_release.nginx_ingress]
  name            = "dex"
  repository      = "https://charts.dexidp.io"
  chart           = "dex"
  cleanup_on_fail = true
  atomic          = true

  set = [
    {
      name  = "image.repository"
      value = "docker.io/dexidp/dex"
    },
    {
      name  = "config.issuer"
      value = "https://posts-app.${var.domain}/issuer"
    },
    {
      name  = "config.enablePasswordDB"
      value = true
    },
    {
      name  = "config.storage.type"
      value = "memory"
    },
    {
      name  = "config.web.http"
      value = "0.0.0.0:5556"
    },
    {
      name  = "config.staticPasswords[0].email"
      value = "admin@example.com"
    },
    {
      name  = "config.staticPasswords[0].hash"
      value = "$2a$10$2b2cU8CPhOTaGrs1HRQuAueS7JTT5ZHsHSzYiFPm1leZck7Mc8T4W"
    },
    {
      name  = "config.staticPasswords[0].username"
      value = "admin"
    },
    {
      name  = "config.staticPasswords[0].userID"
      value = "08a8684b-db88-4b73-90a9-3cd1661f5466"
    },
    {
      name  = "config.staticClients[0].id"
      value = "private-client"
    },
    {
      name  = "config.staticClients[0].secret"
      value = "app-secret"
    },
    {
      name  = "config.staticClients[0].name"
      value = "Private Client"
    },
            {
      name  = "config.staticClients[0].redirectURIs[0]"
      value = "https://posts-app.${var.domain}/issuer/callback"
    },
    {
      name  = "config.oauth2.passwordConnector"
      value = "local"
    },
    {
      name  = "ingress.hosts[0].host"
      value = "posts-app.${var.domain}"
    },
    {
      name  = "ingress.hosts[0].paths[0].path"
      value = "/issuer"
    },
    {
      name  = "ingress.hosts[0].paths[0].pathType"
      value = "Prefix"
    },
    {
      name  = "ingress.enabled"
      value = true
    },
    {
      name  = "ingress.className"
      value = "nginx"
    }
  ]
}
*/


