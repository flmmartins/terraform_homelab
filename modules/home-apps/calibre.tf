variable "calibre_enabled" {
  description = "Whether to deploy Calibre-Web-Automated"
  type        = bool
  default     = true
}

variable "calibre_image_tag" {
  description = "Calibre-Web-Automated image tag. Check https://github.com/crocodilestick/Calibre-Web-Automated/releases for latest"
  type        = string
  default     = "v4.0.6"
}

variable "calibre_vault_password" {
  description = <<-EOT
    Vault configuration to read the DeDRM plugin's key file (dedrm.json) from.
    If not provided, DeDRM will remain unconfigured (no keys) and DRM'd books will fail to convert.

    Example:
    calibre_vault_password = {
      secret_path         = "secret/calibre-dedrm"
      vault_address       = "https://vault.internal:8200"
      json_field          = "dedrm_json"
      activation_field    = "activation_xml"
      device_field        = "device_xml"
      device_salt_field   = "devicesalt"
    }
  EOT
  type = object({
    secret_path            = optional(string)
    vault_address          = optional(string)
    vault_csi_ca_cert_path = optional(string, "/vault/tls/ca.crt")
    json_field             = optional(string, "dedrm_json")
    activation_field       = optional(string, "activation_xml")
    device_field           = optional(string, "device_xml")
    device_salt_field      = optional(string, "devicesalt")
  })
  default = null
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

  calibre_plugins = fileset(
    "${path.module}/calibre_plugins",
    "*.zip"
  )

  calibre_plugins_checksum = sha256(join("", [
    for f in sort(tolist(local.calibre_plugins)) :
    "${f}:${filesha256("${path.module}/calibre_plugins/${f}")}"
  ]))
}


resource "kubernetes_namespace_v1" "calibre" {
  count = var.ebooks_comics_nfs_share != null ? 1 : 0

  metadata {
    name   = local.calibre_app_name
    labels = local.calibre_common_labels
  }
}

resource "kubernetes_service_account_v1" "calibre" {
  count = var.calibre_enabled ? 1 : 0

  metadata {
    name      = local.calibre_app_name
    namespace = kubernetes_namespace_v1.calibre[0].metadata[0].name
    labels    = local.calibre_common_labels
  }
}

resource "vault_policy" "calibre" {
  count = var.calibre_vault_password != null ? 1 : 0

  name   = local.calibre_app_name
  policy = <<EOT
path "${var.calibre_vault_password.secret_path}" { capabilities = ["read"] }
EOT
}

resource "vault_kubernetes_auth_backend_role" "calibre" {
  count = var.calibre_vault_password != null ? 1 : 0

  role_name                        = local.calibre_app_name
  bound_service_account_names      = [kubernetes_service_account_v1.calibre[0].metadata[0].name]
  bound_service_account_namespaces = [kubernetes_namespace_v1.calibre[0].metadata[0].name]
  token_max_ttl                    = 1440
  token_policies                   = [vault_policy.calibre[0].name]
}

# Tried to do with vault agent but it got messy with templating using annotation
resource "kubernetes_manifest" "calibre" {
  count = var.calibre_vault_password != null ? 1 : 0

  manifest = {
    apiVersion = "secrets-store.csi.x-k8s.io/v1"
    kind       = "SecretProviderClass"
    metadata = {
      name      = local.calibre_app_name
      namespace = kubernetes_namespace_v1.calibre[0].metadata[0].name
      labels    = local.calibre_common_labels
    }
    spec = {
      provider = "vault"
      parameters = {
        roleName        = vault_kubernetes_auth_backend_role.calibre[0].role_name
        vaultAddress    = var.calibre_vault_password.vault_address
        vaultCACertPath = var.calibre_vault_password.vault_csi_ca_cert_path
        objects         = <<EOT
- objectName: dedrm.json
  secretPath: ${var.calibre_vault_password.secret_path}
  secretKey: ${var.calibre_vault_password.json_field}
- objectName: activation.xml
  secretPath: ${var.calibre_vault_password.secret_path}
  secretKey: ${var.calibre_vault_password.activation_field}
- objectName: device.xml
  secretPath: ${var.calibre_vault_password.secret_path}
  secretKey: ${var.calibre_vault_password.device_field}
- objectName: devicesalt
  secretPath: ${var.calibre_vault_password.secret_path}
  secretKey: ${var.calibre_vault_password.device_salt_field}
        EOT
      }
    }
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

# To convert books with DRM
resource "kubernetes_persistent_volume_claim_v1" "calibre_ingest" {
  count = var.ebooks_comics_nfs_share != null ? 1 : 0

  metadata {
    name      = "${local.calibre_app_name}-ingest"
    namespace = kubernetes_namespace_v1.calibre[0].metadata[0].name

    labels = merge(local.calibre_common_labels, {
      component = "ingest"
    })
  }

  spec {
    access_modes = [var.ebooks_comics_nfs_share.access_mode]

    resources {
      requests = {
        storage = "1Gi"
      }
    }

    volume_name        = kubernetes_persistent_volume_v1.calibre_ingest[0].metadata[0].name
    storage_class_name = kubernetes_storage_class_v1.manual.metadata[0].name
  }
}

resource "kubernetes_config_map_v1" "calibre_plugins" {
  count = var.calibre_enabled ? 1 : 0

  metadata {
    name      = "${local.calibre_app_name}-plugins"
    namespace = kubernetes_namespace_v1.calibre[0].metadata[0].name

    labels = local.calibre_common_labels
  }

  binary_data = {
    for f in local.calibre_plugins :
    f => filebase64("${path.module}/calibre_plugins/${f}")
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

        annotations = {
          "calibre/plugins-checksum" = local.calibre_plugins_checksum
        }
      }

      spec {
        # CWA's s6-init requires starting as root because
        # it chowns mounted paths to PUID/PGID.
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

        service_account_name = var.calibre_vault_password != null ? kubernetes_service_account_v1.calibre[0].metadata[0].name : null

        init_container {
          name  = "install-calibre-plugins"
          image = "docker.io/crocodilestick/calibre-web-automated:${var.calibre_image_tag}"

          command = [
            "sh", "-c",
            <<-EOT
            set -eu

            export CALIBRE_CONFIG_DIRECTORY=/config/.config/calibre
            export PATH="/app/calibre:$PATH"

            mkdir -p "$CALIBRE_CONFIG_DIRECTORY/plugins"
            mkdir -p "$CALIBRE_CONFIG_DIRECTORY/plugins/DeACSM/account"

            for plugin in /plugin-source/*.zip; do
              echo "Installing $plugin"
              /app/calibre/calibre-customize -a "$plugin"
            done

            %{~if var.calibre_vault_password != null~}
            echo "Installing DeDRM keys"
            cp /mnt/secrets-store/dedrm.json "$CALIBRE_CONFIG_DIRECTORY/plugins/dedrm.json"
            chown ${var.ebooks_comics_nfs_share.user_id}:${var.ebooks_comics_nfs_share.group_id} "$CALIBRE_CONFIG_DIRECTORY/plugins/dedrm.json"
            chmod 600 "$CALIBRE_CONFIG_DIRECTORY/plugins/dedrm.json"
            cp /mnt/secrets-store/activation.xml "$CALIBRE_CONFIG_DIRECTORY/plugins/DeACSM/account/activation.xml"
            cp /mnt/secrets-store/device.xml "$CALIBRE_CONFIG_DIRECTORY/plugins/DeACSM/account/device.xml"
            base64 -d /mnt/secrets-store/devicesalt > "$CALIBRE_CONFIG_DIRECTORY/plugins/DeACSM/account/devicesalt"
            chown -R ${var.ebooks_comics_nfs_share.user_id}:${var.ebooks_comics_nfs_share.group_id} "$CALIBRE_CONFIG_DIRECTORY/plugins/DeACSM/account"
            chmod -R 700 "$CALIBRE_CONFIG_DIRECTORY/plugins/DeACSM/account"
            %{~endif~}

            echo "Installed plugins:"
            /app/calibre/calibre-customize -l
            EOT
          ]

          volume_mount {
            name       = "config"
            mount_path = "/config"
          }
          volume_mount {
            name       = "plugins"
            mount_path = "/plugin-source"
            read_only  = true
          }
          dynamic "volume_mount" {
            for_each = var.calibre_vault_password != null ? [1] : []
            content {
              name       = "dedrm-secret"
              mount_path = "/mnt/secrets-store"
              read_only  = true
            }
          }
        }

        container {
          name = local.calibre_app_name

          image = "docker.io/crocodilestick/calibre-web-automated:${var.calibre_image_tag}"

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
            # Automatically convert books dropped into the ingest folder.
            name  = "CWA_AUTOCONVERT"
            value = "true"
          }
          env {
            # Recommended by CWA for NFS/SMB.
            name  = "NETWORK_SHARE_MODE"
            value = "true"
          }
          env {
            # Enable Calibre user plugins.
            name  = "CWA_CALIBRE_USER_PLUGINS"
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
              add = [
                "CHOWN",
                "SETUID",
                "SETGID",
                "DAC_OVERRIDE",
                "FOWNER"
              ]
            }
          }

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
            mount_path = "/cwa-book-ingest"
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
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.calibre_ingest[0].metadata[0].name
          }
        }
        volume {
          name = "plugins"
          config_map {
            name = kubernetes_config_map_v1.calibre_plugins[0].metadata[0].name
          }
        }
        dynamic "volume" {
          for_each = var.calibre_vault_password != null ? [1] : []
          content {
            name = "dedrm-secret"
            csi {
              driver    = "secrets-store.csi.k8s.io"
              read_only = true
              volume_attributes = {
                secretProviderClass = kubernetes_manifest.calibre[0].manifest.metadata.name
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "calibre" {
  depends_on = [kubernetes_deployment_v1.calibre]
  count      = var.calibre_enabled ? 1 : 0

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
  count = var.calibre_enabled ? 1 : 0

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

      hostnames = [
        local.calibre_url
      ]

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
