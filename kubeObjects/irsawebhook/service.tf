resource "kubernetes_manifest" "service_pod_identity_webhook" {
  manifest = {
    "apiVersion" = "v1"
    "kind" = "Service"
    "metadata" = {
      "annotations" = {
        "prometheus.io/port" = "443"
        "prometheus.io/scheme" = "https"
        "prometheus.io/scrape" = "true"
      }
      "name" = "pod-identity-webhook"
      "namespace" = "${var.ns}"
    }
    "spec" = {
      "ports" = [
        {
          "port" = 443
          "targetPort" = 443
        },
      ]
      "selector" = {
        "app" = "pod-identity-webhook"
      }
    }
  }
}
