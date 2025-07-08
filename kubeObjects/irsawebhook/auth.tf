resource "kubernetes_manifest" "serviceaccount_pod_identity_webhook" {
  manifest = {
    "apiVersion" = "v1"
    "kind" = "ServiceAccount"
    "metadata" = {
      "name" = "pod-identity-webhook"
      "namespace" = "default"
    }
  }
}

resource "kubernetes_manifest" "role_pod_identity_webhook" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind" = "Role"
    "metadata" = {
      "name" = "pod-identity-webhook"
      "namespace" = "default"
    }
    "rules" = [
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "secrets",
        ]
        "verbs" = [
          "create",
        ]
      },
      {
        "apiGroups" = [
          "",
        ]
        "resourceNames" = [
          "pod-identity-webhook",
        ]
        "resources" = [
          "secrets",
        ]
        "verbs" = [
          "get",
          "update",
          "patch",
        ]
      },
    ]
  }
}

resource "kubernetes_manifest" "rolebinding_pod_identity_webhook" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind" = "RoleBinding"
    "metadata" = {
      "name" = "pod-identity-webhook"
      "namespace" = "default"
    }
    "roleRef" = {
      "apiGroup" = "rbac.authorization.k8s.io"
      "kind" = "Role"
      "name" = "pod-identity-webhook"
    }
    "subjects" = [
      {
        "kind" = "ServiceAccount"
        "name" = "pod-identity-webhook"
        "namespace" = "default"
      },
    ]
  }
}

resource "kubernetes_manifest" "clusterrole_pod_identity_webhook" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind" = "ClusterRole"
    "metadata" = {
      "name" = "pod-identity-webhook"
    }
    "rules" = [
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "serviceaccounts",
        ]
        "verbs" = [
          "get",
          "watch",
          "list",
        ]
      },
      {
        "apiGroups" = [
          "certificates.k8s.io",
        ]
        "resources" = [
          "certificatesigningrequests",
        ]
        "verbs" = [
          "create",
          "get",
          "list",
          "watch",
        ]
      },
    ]
  }
}

resource "kubernetes_manifest" "clusterrolebinding_pod_identity_webhook" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind" = "ClusterRoleBinding"
    "metadata" = {
      "name" = "pod-identity-webhook"
    }
    "roleRef" = {
      "apiGroup" = "rbac.authorization.k8s.io"
      "kind" = "ClusterRole"
      "name" = "pod-identity-webhook"
    }
    "subjects" = [
      {
        "kind" = "ServiceAccount"
        "name" = "pod-identity-webhook"
        "namespace" = "default"
      },
    ]
  }
}
