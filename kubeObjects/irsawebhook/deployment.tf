resource "kubernetes_manifest" "deployment_pod_identity_webhook" {
  manifest = {
    "apiVersion" = "apps/v1"
    "kind" = "Deployment"
    "metadata" = {
      "name" = "pod-identity-webhook"
      "namespace" = "${var.ns}"
    }
    "spec" = {
      "replicas" = 1
      "selector" = {
        "matchLabels" = {
          "app" = "pod-identity-webhook"
        }
      }
      "template" = {
        "metadata" = {
          "labels" = {
            "app" = "pod-identity-webhook"
          }
        }
        "spec" = {
          "nodeSelector" = {
             "kubernetes.io/arch" = "arm64"
          }
          "containers" = [
            {
              "command" = [
                "/webhook",
                "--in-cluster=false",
                "--namespace=${var.ns}",
                "--service-name=pod-identity-webhook",
                "--annotation-prefix=kubernetes",
                "--token-audience=sts.amazonaws.com",
                "--sts-regional-endpoint=true",
                "--logtostderr",
              ]
              "image" = "amazon/amazon-eks-pod-identity-webhook:latest"
              "imagePullPolicy" = "Always"
              "name" = "pod-identity-webhook"
              "volumeMounts" = [
                {
                  "mountPath" = "/etc/webhook/certs"
                  "name" = "cert"
                  "readOnly" = true
                },
              ]
            },
          ]
          "serviceAccountName" = "pod-identity-webhook-${var.ns}"
          "volumes" = [
            {
              "name" = "cert"
              "secret" = {
                "secretName" = "pod-identity-webhook-cert"
              }
            },
          ]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "clusterissuer_selfsigned" {
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind" = "ClusterIssuer"
    "metadata" = {
      "name" = "selfsigned-${var.ns}"
    }
    "spec" = {
      "selfSigned" = {}
    }
  }
}

resource "kubernetes_manifest" "certificate_pod_identity_webhook" {
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind" = "Certificate"
    "metadata" = {
      "name" = "pod-identity-webhook"
      "namespace" = "${var.ns}"
    }
    "spec" = {
      "commonName" = "pod-identity-webhook.${var.ns}.svc"
      "dnsNames" = [
        "pod-identity-webhook",
        "pod-identity-webhook.${var.ns}",
        "pod-identity-webhook.${var.ns}.svc",
        "pod-identity-webhook.${var.ns}.svc.local",
      ]
      "duration" = "2160h"
      "isCA" = true
      "issuerRef" = {
        "kind" = "ClusterIssuer"
        "name" = "selfsigned"
      }
      "renewBefore" = "360h"
      "secretName" = "pod-identity-webhook-cert"
    }
  }
}
