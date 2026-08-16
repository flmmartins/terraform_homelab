variable "bindery_enabled" {
  description = "Whether to deploy Bindery (ebook/comic converter)"
  type        = bool
  default     = false
}

variable "bindery_image_tag" {
  description = "Bindery image tag. Check https://hub.docker.com/r/dinkeyes/bindery/tags for latest"
  type        = string
  default     = "4.3.1"
}

locals {
  bindery_app_name = "bindery-ebook-converter"
  bindery_url      = "ebookconverter.${var.domain}"
  bindery_port     = 5000
  bindery_common_labels = {
    "part-of" = "ebook-converter"
  }
  bindery_app_labels = merge(local.bindery_common_labels, {
    component = "app"
  })
}

resource "kubernetes_namespace_v1" "bindery" {
  count = var.bindery_enabled ? 1 : 0

  metadata {
    name   = local.bindery_app_name
    labels = local.bindery_common_labels
  }
}

resource "kubernetes_persistent_volume_claim_v1" "bindery_config" {
  count = var.bindery_enabled ? 1 : 0

  metadata {
    name      = "${local.bindery_app_name}-config"
    namespace = kubernetes_namespace_v1.bindery[0].metadata[0].name
    labels = merge(local.bindery_common_labels, {
      component = "config"
    })
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
    storage_class_name = var.persistent_storage_class
  }
}

# For kobo, change output to .kepub.epub for best results
resource "kubernetes_deployment_v1" "bindery" {
  count = var.bindery_enabled ? 1 : 0

  metadata {
    name      = local.bindery_app_name
    namespace = kubernetes_namespace_v1.bindery[0].metadata[0].name
    labels    = local.bindery_app_labels
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = local.bindery_app_labels
    }

    template {
      metadata {
        labels = local.bindery_app_labels
      }

      spec {
        # Bindery's entrypoint chowns mounted paths to PUID/PGID on startup,
        # which requires starting as root - same constraint as Plex (see Plex.md).
        # Safe here because all volumes are emptyDir, not NFS.
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"
                label_selector {
                  match_expressions {
                    key      = "component"
                    operator = "In"
                    values   = ["app"]
                  }
                }
              }
            }
          }
        }

        container {
          name  = local.bindery_app_name
          image = "docker.io/dinkeyes/bindery:${var.bindery_image_tag}"

          port {
            container_port = local.bindery_port
          }

          env {
            name  = "PUID"
            value = var.ebooks_comics_nfs_share.user_id
          }

          env {
            name  = "PGID"
            value = var.ebooks_comics_nfs_share.group_id
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "1"
              memory = "1Gi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
              # Needed for the entrypoint's chown-then-drop-privileges step
              add = ["CHOWN", "SETUID", "SETGID"]
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/app/config"
          }
          volume_mount {
            name       = "books-in"
            mount_path = "/Books_in"
          }
          volume_mount {
            name       = "books-out"
            mount_path = "/Books_out"
          }
          volume_mount {
            name       = "comics-in"
            mount_path = "/Comics_in"
          }
          volume_mount {
            name       = "comics-out"
            mount_path = "/Comics_out"
          }
          volume_mount {
            name       = "comics-raw"
            mount_path = "/Comics_raw"
          }
        }

        volume {
          name = "config"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.bindery_config[0].metadata[0].name
          }
        }
        volume {
          name = "books-in"
          empty_dir {}
        }
        volume {
          name = "books-out"
          empty_dir {}
        }
        volume {
          name = "comics-in"
          empty_dir {}
        }
        volume {
          name = "comics-out"
          empty_dir {}
        }
        volume {
          name = "comics-raw"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "bindery" {
  count = var.bindery_enabled ? 1 : 0

  metadata {
    name      = local.bindery_app_name
    namespace = kubernetes_namespace_v1.bindery[0].metadata[0].name
    labels = merge(local.bindery_common_labels, {
      component = "service"
    })
  }

  spec {
    selector = local.bindery_app_labels

    port {
      port        = 80
      target_port = local.bindery_port
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_manifest" "httproute_bindery" {
  count      = var.bindery_enabled ? 1 : 0
  depends_on = [kubernetes_deployment_v1.bindery]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"

    metadata = {
      name      = local.bindery_app_name
      namespace = kubernetes_namespace_v1.bindery[0].metadata[0].name
      labels = merge(local.bindery_common_labels, {
        component = "httproute"
      })
    }

    spec = {
      parentRefs = [
        {
          name      = var.gateway.name
          namespace = var.gateway.namespace
        }
      ]

      hostnames = [local.bindery_url]

      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]

          backendRefs = [
            {
              name = kubernetes_service_v1.bindery[0].metadata[0].name
              port = 80
            }
          ]
        }
      ]
    }
  }
}
