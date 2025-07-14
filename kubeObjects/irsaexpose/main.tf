resource "kubernetes_config_map" "python_server_script" {
  metadata {
    name = "irsa-expose-script"
  }

  data = {
    "irsaexpose.py" = "${file("${path.module}/server/webserver.py")}"
  }
}

resource "kubernetes_deployment" "irsa_expose_deployment" {
  depends_on = [kubernetes_config_map.python_server_script]
  metadata {
    name = "irsa-expose"
    labels = {
      test = "IRSAExpose"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        test = "IRSAExpose"
      }
    }

    template {
      metadata {
        labels = {
          test = "IRSAExpose"
        }
      }

      spec {

        node_selector = {
          "kubernetes.io/arch" = "arm64"
        }

        volume {
          name = "script-load"
          config_map {
            name = "irsa-expose-script"
          }
        }
        volume {
          name = "web-dir"
          empty_dir {
            size_limit = "10Mi"
          }
        }

        container {
          image = "python:alpine"
          name  = "irsaserver"
          port {
            container_port = 8000
          }

          volume_mount {
            name       = "script-load"
            mount_path = "/mnt"
          }

          volume_mount {
            name       = "web-dir"
            mount_path = "/web/www/"
            read_only  = false
          }

          working_dir = "/web/www/"

          args    = ["/mnt/irsaexpose.py"]
          command = ["python3"]

          env {
            name  = "DOMAIN"
            value = "kubeadmin.${var.domain}"
          }
          env {
            name  = "KUBERNETES_ENDPOINT"
            value = "kubernetes.default.svc.cluster.local"
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
              path = "/.well-known/openid-configuration"
              port = 8000
            }

            initial_delay_seconds = 3
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "irsa_expose_service" {
  metadata {
    name = "irsa-expose"
  }
  spec {
    selector = {
      test = "IRSAExpose"
    }
    port {
      port        = 80
      target_port = 8000
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "irsa_expose_ingress" {
  metadata {
    name = "irsa-expose-ingress"
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "kubeadmin.${var.domain}"
      http {
        path {
          backend {
            service {
              name = "irsa-expose"
              port {
                number = 80
              }
            }
          }
          path      = "/.well-known/openid-configuration"
          path_type = "Exact"
        }
        path {
          backend {
            service {
              name = "irsa-expose"
              port {
                number = 80
              }
            }
          }
          path      = "/openid/v1/jwks"
          path_type = "Exact"
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