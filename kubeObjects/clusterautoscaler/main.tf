resource "kubernetes_manifest" "serviceaccount_kube_system_cluster_autoscaler" {
  manifest = {
    "apiVersion" = "v1"
    "kind" = "ServiceAccount"
    "metadata" = {
      "labels" = {
        "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
        "k8s-app" = "cluster-autoscaler"
      }
      "name" = "cluster-autoscaler"
      "namespace" = "kube-system"
      "annotations" = {
        "kubernetes/role-arn" = "${var.service_account_arn}"
      }
    }
  }
}

resource "kubernetes_manifest" "clusterrole_cluster_autoscaler" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind" = "ClusterRole"
    "metadata" = {
      "labels" = {
        "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
        "k8s-app" = "cluster-autoscaler"
      }
      "name" = "cluster-autoscaler"
    }
    "rules" = [
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "events",
          "endpoints",
        ]
        "verbs" = [
          "create",
          "patch",
        ]
      },
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "pods/eviction",
        ]
        "verbs" = [
          "create",
        ]
      },
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "pods/status",
        ]
        "verbs" = [
          "update",
        ]
      },
      {
        "apiGroups" = [
          "",
        ]
        "resourceNames" = [
          "cluster-autoscaler",
        ]
        "resources" = [
          "endpoints",
        ]
        "verbs" = [
          "get",
          "update",
        ]
      },
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "nodes",
        ]
        "verbs" = [
          "watch",
          "list",
          "get",
          "update",
        ]
      },
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "namespaces",
          "pods",
          "services",
          "replicationcontrollers",
          "persistentvolumeclaims",
          "persistentvolumes",
        ]
        "verbs" = [
          "watch",
          "list",
          "get",
        ]
      },
      {
        "apiGroups" = [
          "extensions",
        ]
        "resources" = [
          "replicasets",
          "daemonsets",
        ]
        "verbs" = [
          "watch",
          "list",
          "get",
        ]
      },
      {
        "apiGroups" = [
          "policy",
        ]
        "resources" = [
          "poddisruptionbudgets",
        ]
        "verbs" = [
          "watch",
          "list",
        ]
      },
      {
        "apiGroups" = [
          "apps",
        ]
        "resources" = [
          "statefulsets",
          "replicasets",
          "daemonsets",
        ]
        "verbs" = [
          "watch",
          "list",
          "get",
        ]
      },
      {
        "apiGroups" = [
          "storage.k8s.io",
        ]
        "resources" = [
          "storageclasses",
          "csinodes",
          "csidrivers",
          "csistoragecapacities",
          "volumeattachments",
        ]
        "verbs" = [
          "watch",
          "list",
          "get",
        ]
      },
      {
        "apiGroups" = [
          "batch",
          "extensions",
        ]
        "resources" = [
          "jobs",
        ]
        "verbs" = [
          "get",
          "list",
          "watch",
          "patch",
        ]
      },
      {
        "apiGroups" = [
          "coordination.k8s.io",
        ]
        "resources" = [
          "leases",
        ]
        "verbs" = [
          "create",
        ]
      },
      {
        "apiGroups" = [
          "coordination.k8s.io",
        ]
        "resourceNames" = [
          "cluster-autoscaler",
        ]
        "resources" = [
          "leases",
        ]
        "verbs" = [
          "get",
          "update",
        ]
      },
    ]
  }
}

resource "kubernetes_manifest" "role_kube_system_cluster_autoscaler" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind" = "Role"
    "metadata" = {
      "labels" = {
        "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
        "k8s-app" = "cluster-autoscaler"
      }
      "name" = "cluster-autoscaler"
      "namespace" = "kube-system"
    }
    "rules" = [
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "configmaps",
        ]
        "verbs" = [
          "create",
          "list",
          "watch",
        ]
      },
      {
        "apiGroups" = [
          "",
        ]
        "resourceNames" = [
          "cluster-autoscaler-status",
          "cluster-autoscaler-priority-expander",
        ]
        "resources" = [
          "configmaps",
        ]
        "verbs" = [
          "delete",
          "get",
          "update",
          "watch",
        ]
      },
    ]
  }
}

resource "kubernetes_manifest" "clusterrolebinding_cluster_autoscaler" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind" = "ClusterRoleBinding"
    "metadata" = {
      "labels" = {
        "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
        "k8s-app" = "cluster-autoscaler"
      }
      "name" = "cluster-autoscaler"
    }
    "roleRef" = {
      "apiGroup" = "rbac.authorization.k8s.io"
      "kind" = "ClusterRole"
      "name" = "cluster-autoscaler"
    }
    "subjects" = [
      {
        "kind" = "ServiceAccount"
        "name" = "cluster-autoscaler"
        "namespace" = "kube-system"
      },
    ]
  }
}

resource "kubernetes_manifest" "rolebinding_kube_system_cluster_autoscaler" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind" = "RoleBinding"
    "metadata" = {
      "labels" = {
        "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
        "k8s-app" = "cluster-autoscaler"
      }
      "name" = "cluster-autoscaler"
      "namespace" = "kube-system"
    }
    "roleRef" = {
      "apiGroup" = "rbac.authorization.k8s.io"
      "kind" = "Role"
      "name" = "cluster-autoscaler"
    }
    "subjects" = [
      {
        "kind" = "ServiceAccount"
        "name" = "cluster-autoscaler"
        "namespace" = "kube-system"
      },
    ]
  }
}

resource "kubernetes_manifest" "deployment_kube_system_cluster_autoscaler" {
  manifest = {
    "apiVersion" = "apps/v1"
    "kind" = "Deployment"
    "metadata" = {
      "labels" = {
        "app" = "cluster-autoscaler"
      }
      "name" = "cluster-autoscaler"
      "namespace" = "kube-system"
    }
    "spec" = {
      "replicas" = 1
      "selector" = {
        "matchLabels" = {
          "app" = "cluster-autoscaler"
        }
      }
      "template" = {
        "metadata" = {
          "annotations" = {
            "prometheus.io/port" = "8085"
            "prometheus.io/scrape" = "true"
          }
          "labels" = {
            "app" = "cluster-autoscaler"
          }
        }
        "spec" = {
          "nodeSelector" = {
             "kubernetes.io/arch" = "arm64"
          }
          "containers" = [
            {
              "command" = [
                "./cluster-autoscaler",
                "--v=4",
                "--stderrthreshold=info",
                "--cloud-provider=aws",
                "--skip-nodes-with-local-storage=false",
                "--nodes=1:4:worker_asg",
              ]
              "image" = "registry.k8s.io/autoscaling/cluster-autoscaler:v1.32.1"
              "imagePullPolicy" = "Always"
              "name" = "cluster-autoscaler"
              "resources" = {
                "limits" = {
                  "cpu" = "100m"
                  "memory" = "600Mi"
                }
                "requests" = {
                  "cpu" = "100m"
                  "memory" = "600Mi"
                }
              }
              "securityContext" = {
                "allowPrivilegeEscalation" = false
                "capabilities" = {
                  "drop" = [
                    "ALL",
                  ]
                }
                "readOnlyRootFilesystem" = true
              }
              "volumeMounts" = [
                {
                  "mountPath" = "/etc/ssl/certs/ca-certificates.crt"
                  "name" = "ssl-certs"
                  "readOnly" = true
                },
              ]
            },
          ]
          "priorityClassName" = "system-cluster-critical"
          "securityContext" = {
            "fsGroup" = 65534
            "runAsNonRoot" = true
            "runAsUser" = 65534
            "seccompProfile" = {
              "type" = "RuntimeDefault"
            }
          }
          "serviceAccountName" = "cluster-autoscaler"
          "volumes" = [
            {
              "hostPath" = {
                "path" = "/etc/ssl/certs/ca-bundle.crt"
              }
              "name" = "ssl-certs"
            },
          ]
        }
      }
    }
  }
}
