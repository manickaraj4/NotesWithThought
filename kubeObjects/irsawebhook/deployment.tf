resource "kubernetes_manifest" "deployment_pod_identity_webhook" {
  manifest = {
    "apiVersion" = "apps/v1"
    "kind" = "Deployment"
    "metadata" = {
      "name" = "pod-identity-webhook"
      "namespace" = "default"
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
          "containers" = [
            {
              "command" = [
                "/webhook",
                "--in-cluster=false",
                "--namespace=default",
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
          "serviceAccountName" = "pod-identity-webhook"
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
      "name" = "selfsigned"
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
      "namespace" = "default"
    }
    "spec" = {
      "commonName" = "pod-identity-webhook.default.svc"
      "dnsNames" = [
        "pod-identity-webhook",
        "pod-identity-webhook.default",
        "pod-identity-webhook.default.svc",
        "pod-identity-webhook.default.svc.local",
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
