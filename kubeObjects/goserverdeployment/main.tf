/* data "aws_ecr_authorization_token" "ecr_token" {
} */

data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "lb_cert_id" {
  name = "DomainCertId"
}

data "aws_ssm_parameter" "db_host" {
  name = "kube_db_host"
}


data "aws_ssm_parameter" "github_oauth_id" {
  name = "GithubOAuthID"
  with_decryption = true
}

data "aws_ssm_parameter" "github_oauth_secret" {
  name = "GithubOAuthSecret"
  with_decryption = true
}

/* resource "kubernetes_secret" "docker_token_secret-default" {
  metadata {
    name      = "docker-cfg-default"
    namespace = "default"
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
} */

resource "kubernetes_deployment" "go_server_deployment" {
  metadata {
    name = "posts-app"
    labels = {
      test = "GoServerApp"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        test = "GoServerApp"
      }
    }

    template {
      metadata {
        labels = {
          test = "GoServerApp"
        }
      }

      spec {

/*         image_pull_secrets {
          name = "docker-cfg-default"
        } */

        node_selector = {
          "kubernetes.io/arch" = "amd64"
        }

        container {
          image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/apprepo:latest"
          name  = "goserver"
          port {
            container_port = 8080
          }

          env {
            name = "GITHUB_OAUTH2_CLIENT_ID" 
            value = "${data.aws_ssm_parameter.github_oauth_id.value}"
          }
          env {
            name = "GITHUB_OAUTH2_CLIENT_SECRET" 
            value = "${data.aws_ssm_parameter.github_oauth_secret.value}"
          }
          env {
            name = "DOMAIN" 
            value = "${var.domain}"
          }
          env {
            name = "AWS_REGION" 
            value = "${var.aws_region}"
          }

          env {
            name = "DB_HOST" 
            value = "${data.aws_ssm_parameter.db_host.value}"
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/healthcheck"
              port = 8080
            }

            initial_delay_seconds = 3
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "post_service" {
  metadata {
    name = "posts-app"
    /* annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-ssl-ports" : "https"
      "service.beta.kubernetes.io/aws-load-balancer-ssl-cert" : "arn:aws:acm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:certificate/${data.aws_ssm_parameter.lb_cert_id.value}"
      "service.beta.kubernetes.io/aws-load-balancer-type" : "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout" : "60"
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type": "instance"
    } */
  }
  spec {
    selector = {
      test = "GoServerApp"
    }
    #session_affinity = "ClientIP"
    port {
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }

    #load_balancer_class = "service.k8s.aws/nlb"
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "post_service_ingress" {
  metadata {
    name = "postservice-ingress"
    /*     annotations = {
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "instance"
      "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\": 80}]"
      "alb.ingress.kubernetes.io/certificate-arn"  = "arn:aws:acm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:certificate/${data.aws_ssm_parameter.lb_cert_id.value}"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/posts"
      "alb.ingress.kubernetes.io/healthcheck-port" = "8080"
      "alb.ingress.kubernetes.io/success-codes"    = "200-404" 
    } */
  }

  spec {
    ingress_class_name = "nginx"
    /*     default_backend {
      service {
        name = "posts-app"
        port {
          number = 80
        }
      }
    }  */

    rule {
      host = "posts.${var.domain}"
      http {
        path {
          backend {
            service {
              name = "posts-app"
              port {
                number = 80
              }
            }
          }
          path      = "/"
          path_type = "Prefix"
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "kubernetes_apiserver_ingress" {
  metadata {
    name = "kubernetes-apiserver-ingress"
    annotations = {
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
      #"nginx.ingress.kubernetes.io/ssl-passthrough" = "true"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "kubeadmin.${var.domain}"
      http {
        path {
          backend {
            service {
              name = "kubernetes"
              port {
                number = 443
              }
            }
          }
          path      = "/"
          path_type = "Prefix"
        }
      }
    }
  }
} 