variable "calibre_enabled" {
  description = "Whether to deploy Calibre-Web-Automated"
  type        = bool
  default     = true
}

variable "cwa_image_tag" {
  description = "Calibre-Web-Automated image tag. Check https://github.com/crocodilestick/Calibre-Web-Automated/releases for latest"
  type        = string
  default     = "v4.0.6"
}


locals {
  calibre_app_name = "calibre"
  calibre_url      = "reader.${var.domain}"
  calibre_port     = 8083
  calibre_common_labels = {
    "part-of" = "reader"
  }
  calibre_app_labels = merge(local.calibre_common_labels, {
    component = "calibre"
  })
}

resource "kubernetes_namespace_v1" "calibre" {
  count = var.ebooks_comics_nfs_share != null ? 1 : 0

  metadata {
    name   = local.calibre_app_name
    labels = local.calibre_common_labels
  }
}

resource "kubernetes_persistent_volume_claim_v1" "calibre_config" {
  count = var.ebooks_comics_nfs_share != null ? 1 : 0

  metadata {
    name      = "${local.calibre_app_name}-config"
    namespace = kubernetes_namespace_v1.calibre[0].metadata[0].name
    labels = merge(local.calibre_common_labels, {
      component = "config"
    })
  }

  spec {
    access_modes = [var.ebooks_comics_nfs_share.access_mode]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
    storage_class_name = var.persistent_storage_class
  }
}

resource "kubernetes_persistent_volume_claim_v1" "calibre_library" {
  count = var.ebooks_comics_nfs_share != null ? 1 : 0

  metadata {
    name      = "${local.calibre_app_name}-library"
    namespace = kubernetes_namespace_v1.calibre[0].metadata[0].name
    labels = merge(local.calibre_common_labels, {
      component = "data"
    })
  }

  spec {
    access_modes = [var.ebooks_comics_nfs_share.access_mode]
    resources {
      requests = {
        storage = var.ebooks_comics_nfs_share.size
      }
    }
    volume_name        = kubernetes_persistent_volume_v1.calibre_library[0].metadata[0].name
    storage_class_name = kubernetes_storage_class_v1.manual.metadata[0].name
  }
}

resource "kubernetes_deployment_v1" "calibre" {
  count = var.calibre_enabled ? 1 : 0

  metadata {
    name      = local.calibre_app_name
    namespace = kubernetes_namespace_v1.calibre[0].metadata[0].name
    labels    = local.calibre_app_labels
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = local.calibre_app_labels
    }

    template {
      metadata {
        labels = local.calibre_app_labels
      }

      spec {
        # Entrypoint (linuxserver-style s6-init) chowns mounted paths to PUID/PGID
        # on startup and requires starting as root - same constraint as Plex/Bindery.
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
                    values   = ["calibre"]
                  }
                }
              }
            }
          }
        }

        container {
          name  = local.calibre_app_name
          image = "docker.io/crocodilestick/calibre-web-automated:${var.cwa_image_tag}"

          port {
            container_port = local.calibre_port
          }

          env {
            name  = "PUID"
            value = var.ebooks_comics_nfs_share.user_id
          }
          env {
            name  = "PGID"
            value = var.ebooks_comics_nfs_share.group_id
          }
          env {
            name  = "TZ"
            value = "Europe/Amsterdam"
          }
          env {
            # Auto-converts anything dropped into the ingest folder (azw3, mobi, pdf, etc.) to EPUB
            name  = "CWA_AUTOCONVERT"
            value = "true"
          }
          env {
            # Recommended by CWA when /config or /calibre-library sit on NFS/SMB
            name  = "NETWORK_SHARE_MODE"
            value = "true"
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "1"
              memory = "2Gi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
              add  = ["CHOWN", "SETUID", "SETGID", "DAC_OVERRIDE", "FOWNER"]
            }
          }

          # Never edit paths. The app is very opinionated on folder names
          volume_mount {
            name       = "config"
            mount_path = "/config"
          }
          volume_mount {
            name       = "library"
            mount_path = "/calibre-library"
          }
          volume_mount {
            name       = "ingest"
            mount_path = "/calibre-book-ingest"
          }
        }

        volume {
          name = "config"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.calibre_config[0].metadata[0].name
          }
        }
        volume {
          name = "library"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.calibre_library[0].metadata[0].name
          }
        }
        volume {
          name = "ingest"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "calibre" {
  count = var.calibre_enabled ? 1 : 0

  metadata {
    name      = local.calibre_app_name
    namespace = kubernetes_namespace_v1.calibre[0].metadata[0].name
    labels = merge(local.calibre_common_labels, {
      component = "service"
    })
  }

  spec {
    selector = local.calibre_app_labels

    port {
      port        = 80
      target_port = local.calibre_port
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_manifest" "httproute_calibre" {
  count      = var.calibre_enabled ? 1 : 0
  depends_on = [kubernetes_deployment_v1.calibre]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"

    metadata = {
      name      = local.calibre_app_name
      namespace = kubernetes_namespace_v1.calibre[0].metadata[0].name
      labels = merge(local.calibre_common_labels, {
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

      hostnames = [local.calibre_url]

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
              name = kubernetes_service_v1.calibre[0].metadata[0].name
              port = 80
            }
          ]
        }
      ]
    }
  }
}
