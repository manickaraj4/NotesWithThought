data "aws_ecr_authorization_token" "ecr_token" {
}

data "aws_caller_identity" "current" {}

resource "kubernetes_secret" "docker_token_secret-default" {
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
}

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

        image_pull_secrets {
          name = "docker-cfg-default"
        }

        container {
          image = "989125398105.dkr.ecr.ap-south-1.amazonaws.com/apprepo:latest"
          name  = "goserver"
          port {
            container_port = 8080
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
              path = "/posts"
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
  }
  spec {
    selector = {
      test = "GoServerApp"
    }
    #session_affinity = "ClientIP"
    port {
      port        = 80
      target_port = 8080
    }

    type = "ClusterIP"
  }
}