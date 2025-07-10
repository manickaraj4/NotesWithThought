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

data "aws_ssm_parameter" "prometheus_password" {
  name            = "prometheus_password"
  with_decryption = true
}

data "aws_ssm_parameter" "prometheus_database" {
  name            = "kube_db_host"
}

/* resource "kubernetes_secret" "prometheus_secret" {
  metadata {
    name = "prometheus-secret"
  }

  data = {
    mysqlpassword = data.aws_ssm_parameter.prometheus_password.value
  }
} */

resource "kubernetes_secret" "grafana_secret" {
  metadata {
    name = "grafana-secret"
  }

  data = {
    admin-user = "admin"
    admin-password = data.aws_ssm_parameter.prometheus_password.value
  }
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

/*
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
*/

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

module "irsa_expose_deployment" {
  depends_on = [helm_release.flannel_cni]
  source     = "./irsaexpose"

  domain     = var.domain
} 

/* module "cluster-autoscaler" {
  depends_on = [helm_release.flannel_cni]
  source     = "./clusterautoscaler"

  service_account_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/kube-system_cluster-autoscaler"
} */

resource "helm_release" "metrics_server" {
  depends_on      = [helm_release.flannel_cni]
  name            = "metrics-server"
  repository      = "https://kubernetes-sigs.github.io/metrics-server/"
  chart           = "metrics-server"
  cleanup_on_fail = true
  atomic          = true

  set = [
    {
      name  = "args[0]"
      value = "--kubelet-insecure-tls"
    }
  ]
}

resource "kubernetes_config_map" "kubectl_cm" {
  metadata {
    name = "kubectl-cm"
  }

  data = {
    "kubectl.yaml" = templatefile("${path.module}/kube-state-metrics/kubectl.yaml", { domain = "${var.domain}" })
  }
}

resource "helm_release" "prometheus_server" {
  depends_on      = [helm_release.flannel_cni, helm_release.aws_ebs_csi_driver, kubernetes_config_map.kubectl_cm]
  name            = "prometheus-community"
  repository      = "https://prometheus-community.github.io/helm-charts"
  chart           = "prometheus"
  cleanup_on_fail = true
  atomic          = true

  set = [
    {
      name  = "server.persistentVolume.enabled"
      value = false
    },
    {
      name  = "alertmanager.persistence.enabled"
      value = false
    },
    {
      name  = "kube-state-metrics.extraArgs[0]"
      value = "--kubeconfig=/mnt/kubectl.yaml"
    },
    {
      name  = "kube-state-metrics.volumes[0].configMap.name"
      value = "kubectl-cm"
    },
    {
      name  = "kube-state-metrics.volumes[0].name"
      value = "config-vol"
    },
    {
      name  = "kube-state-metrics.volumeMounts[0].mountPath"
      value = "/mnt"
    },
    {
      name  = "kube-state-metrics.volumeMounts[0].name"
      value = "config-vol"
    }
  
  ]
}

/* resource "helm_release" "kube_state_metrics" {
  depends_on      = [helm_release.flannel_cni]
  name            = "kube-state-metrics"
  repository      = "https://kubernetes.github.io/kube-state-metrics"
  chart           = "kube-state-metrics"
  cleanup_on_fail = true
  atomic          = true
} */

/*
resource "helm_release" "prometheus_mysql_exporter" {
  depends_on      = [helm_release.prometheus_server, kubernetes_secret.prometheus_secret]
  name            = "prometheus-mysql-exporter"
  repository      = "https://prometheus-community.github.io/helm-charts"
  chart           = "prometheus-mysql-exporter"
  cleanup_on_fail = true
  atomic          = true

  set = [
    {
      name  = "mysql.db"
      value = "metrics"
    },
    {
      name  = "mysql.host"
      value = data.aws_ssm_parameter.prometheus_database.value
    },
    {
      name  = "mysql.user"
      value = "admin"
    },
    {
      name  = "mysql.existingPasswordSecret.name"
      value = "prometheus-secret"
    },
    {
      name  = "mysql.existingPasswordSecret.key"
      value = "mysqlpassword"
    }
  ]
}
*/

resource "helm_release" "grafana_server" {
  depends_on      = [helm_release.flannel_cni, kubernetes_secret.grafana_secret]
  name            = "grafana"
  repository      = "https://grafana.github.io/helm-charts"
  chart           = "grafana"
  cleanup_on_fail = true
  atomic          = true

  set = [
    {
      name  = "persistence.enabled"
      value = false
    },
    {
      name  = "admin.existingSecret"
      value = "grafana-secret"
    },
      {
      name  = "ingress.enabled"
      value = true
    },
    {
      name  = "ingress.ingressClassName"
      value = "nginx"
    },
    {
      name  = "ingress.hosts[0]"
      value = "grafana.${var.domain}"
    },
  ]
}

/* resource "helm_release" "aws-cloud_controller_manager" {
  depends_on      = [helm_release.flannel_cni]
  name            = "aws-cloud-controller-manager"
  repository      = "https://kubernetes.github.io/cloud-provider-aws"
  chart           = "aws-cloud-controller-manager"
  cleanup_on_fail = true
  atomic          = true
  namespace       = "kube-system"
} */


# removing this from state as it causes issues with terraform
/* module "irsa_webhook_deployment" {
  depends_on = [helm_release.flannel_cni, module.irsa_expose_deployment, helm_release.cert_manager]
  source     = "./irsawebhook"
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
  depends_on      = [helm_release.flannel_cni]
  name            = "aws-ebs-csi-driver"
  repository      = "oci://ghcr.io/deliveryhero/helm-charts"
  chart           = "aws-ebs-csi-driver"
  cleanup_on_fail = true
  atomic          = true
  namespace       = "kube-system"

  set = [
    {
      name  = "controller.serviceAccount.annotations.kubernetes\\/role-arn"
      value = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/kube-system_ebs-csi-controller-sa"
    },
    {
      name  = "node.serviceAccount.annotations.kubernetes\\/role-arn"
      value = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/kube-system_ebs-csi-node-sa"
    }
  ]
  

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
      value = "amd64"
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
      value = "Deployment"
    },
    {
      name  = "controller.replicaCount"
      value = 2
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

resource "kubernetes_config_map_v1_data" "nginx_cm_edit" {
  depends_on = [helm_release.nginx_ingress]
  metadata {
    name = "ingress-nginx-controller"
  }
  data = {
    "strict-validate-path-type" = false
  }
}

resource "kubernetes_storage_class_v1" "ebs_storage_class" {
  depends_on          = [helm_release.aws_ebs_csi_driver]
  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"

  metadata {
    name = "ebs-sc"
  }
}

resource "helm_release" "cert_manager" {
  depends_on      = [helm_release.flannel_cni]
  name            = "cert-manager"
  repository      = "https://charts.jetstack.io"
  chart           = "cert-manager"
  cleanup_on_fail = true
  atomic          = true

  set = [
    {
      name  = "crds.enabled"
      value = true
    },
    {
      name  = "namespace"
      value = "default"
    }
  ]
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


