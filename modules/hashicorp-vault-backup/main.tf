
locals {
  name               = "vault-raft-backup"
  backup_secret_name = var.create_backup_from_seaweedfs != null ? module.backup_storage[0].secret_name : kubernetes_secret_v1.this[0].metadata[0].name
  backup_bucket_name = var.create_backup_from_seaweedfs != null ? module.backup_storage[0].bucket : var.backup.s3_bucket
  labels             = { part-of = "vault", component = "backup" }
}

resource "terraform_data" "validate_backup_credentials" {
  lifecycle {
    precondition {
      condition     = (var.s3_credentials != null) != (var.create_backup_from_seaweedfs != null)
      error_message = "Exactly one of 's3_credentials' or 'create_backup_from_seaweedfs' must be specified (not both, not neither)."
    }
  }
}

#TODO: test
resource "kubernetes_secret_v1" "this" {
  count = var.backup != null && var.s3_credentials != null ? 1 : 0

  metadata {
    name      = local.name
    namespace = var.vault_namespace
    labels    = local.labels
  }

  data_wo = {
    ACCESS_KEY_ID     = var.s3_credentials.access_key_id
    ACCESS_SECRET_KEY = var.s3_credentials.secret_access_key
  }

  data_wo_revision = 1
}

module "backup_storage" {
  count = var.create_backup_from_seaweedfs != null ? 1 : 0

  source    = "../seadweed-s3-bucket"
  seaweedfs = var.create_backup_from_seaweedfs
  application = {
    name      = local.name
    namespace = var.vault_namespace
  }
  access_key_field = "ACCESS_KEY_ID"
  secret_key_field = "ACCESS_SECRET_KEY"
}

resource "kubernetes_service_account_v1" "this" {
  metadata {
    name      = local.name
    namespace = var.vault_namespace
    labels    = local.labels
  }
}

resource "vault_policy" "this" {
  name = local.name

  policy = <<-EOF
    path "sys/storage/raft/snapshot" {
      capabilities = ["read"]
    }
  EOF
}

resource "vault_kubernetes_auth_backend_role" "this" {
  backend = "kubernetes"

  role_name = local.name

  bound_service_account_names = [
    kubernetes_service_account_v1.this.metadata[0].name
  ]

  bound_service_account_namespaces = [var.vault_namespace]

  token_policies = [vault_policy.this.name]

  token_ttl     = 3600
  token_max_ttl = 3600
}

resource "kubernetes_cron_job_v1" "vault_raft_backup" {
  metadata {
    name      = local.name
    namespace = var.vault_namespace
    labels    = local.labels
  }

  spec {
    schedule                      = var.backup.schedule
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 3


    job_template {
      metadata {}
      spec {
        backoff_limit = 3
        # Safety net: never let a stuck pod hang the job forever
        active_deadline_seconds = 900

        template {
          metadata {
            labels = local.labels
          }
          spec {
            restart_policy       = "Never"
            service_account_name = kubernetes_service_account_v1.this.metadata[0].name

            init_container {
              name  = "vault"
              image = "hashicorp/vault:${var.vault_version}"

              command = ["/bin/sh", "-c"]

              args = [<<-EOT
                set -eu
                JWT="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
                VAULT_TOKEN="$(vault write -field=token auth/kubernetes/login role=${local.name} jwt="$JWT")"
                export VAULT_TOKEN

                SNAPSHOT="/backup/vault-$(date +%Y%m%d-%H%M%S).snap"

                vault operator raft snapshot save "$SNAPSHOT"
                echo "$SNAPSHOT" > /backup/snapshot-path
                echo "Vault snapshot generated"
              EOT
              ]

              env {
                name  = "VAULT_ADDR"
                value = "https://vault-active.${var.vault_namespace}.svc:8200"
              }

              # Vault CLI expects a path to a file here (not the PEM content)
              env {
                name  = "VAULT_CACERT"
                value = "/vault/tls/${var.vault_ca_secret_key}"
              }

              resources {
                requests = {
                  cpu    = var.cpu_request
                  memory = var.memory_request
                }
                limits = {
                  cpu    = var.cpu_limit
                  memory = var.memory_limit
                }
              }

              volume_mount {
                name       = "backup"
                mount_path = "/backup"
              }

              volume_mount {
                name       = "vault-ca"
                mount_path = "/vault/tls"
                read_only  = true
              }
            }

            container {
              name  = "upload"
              image = "amazon/aws-cli:${var.aws_cli_version}"

              env {
                name = "AWS_ACCESS_KEY_ID"

                value_from {
                  secret_key_ref {
                    name = local.backup_secret_name
                    key  = "ACCESS_KEY_ID"
                  }
                }
              }

              env {
                name = "AWS_SECRET_ACCESS_KEY"

                value_from {
                  secret_key_ref {
                    name = local.backup_secret_name
                    key  = "ACCESS_SECRET_KEY"
                  }
                }
              }

              # Read automatically by recent AWS CLI versions, so no --endpoint-url flag needed
              env {
                name  = "AWS_ENDPOINT_URL"
                value = var.backup.s3_endpoint
              }

              env {
                name  = "S3_BUCKET"
                value = local.backup_bucket_name
              }

              command = ["/bin/sh", "-c"]

              # Shell variables use $${...} so Terraform does not try to interpolate them
              args = [<<-EOT
                set -eu

                # Bucket is addressed as host/bucket instead of bucket.host (S3-compatible stores)
                aws configure set default.s3.addressing_style path

                SNAPSHOT="$(ls /backup/vault-*.snap | head -n 1)"
                FILENAME="$(basename "$SNAPSHOT")"

                echo "Uploading $FILENAME..."
                aws s3 cp "$SNAPSHOT" "s3://$${S3_BUCKET}/$${FILENAME}"
                echo "Upload completed."
              EOT
              ]

              resources {
                requests = {
                  cpu    = var.cpu_request
                  memory = var.memory_request
                }
                limits = {
                  cpu    = var.cpu_limit
                  memory = var.memory_limit
                }
              }

              volume_mount {
                name       = "backup"
                mount_path = "/backup"
              }
            }

            volume {
              name = "backup"

              empty_dir {
                size_limit = "10Gi"
              }
            }

            volume {
              name = "vault-ca"

              secret {
                secret_name  = var.vault_ca_secret_name
                default_mode = "0444"

                items {
                  key  = var.vault_ca_secret_key
                  path = var.vault_ca_secret_key
                }
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_manifest" "backup_alerts" {
  count = var.enable_prometheus_alerts == true ? 1 : 0
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = local.name
      namespace = var.vault_namespace
      labels    = local.labels
    }
    spec = {
      groups = [{
        name = local.name
        rules = [
          {
            alert = "VaultBackupJobFailed"
            expr  = "kube_job_failed{namespace=\"${var.vault_namespace}\", job_name=~\"${local.name}.*\", condition=\"true\"} > 0"
            for   = "5m"
            labels = {
              severity = "critical"
            }
            annotations = {
              summary = "Vault backup job {{ $labels.job_name }} failed"
            }
          },
          {
            alert = "VaultBackupStale"
            expr  = "time() - kube_cronjob_status_last_successful_time{namespace=\"${var.vault_namespace}\", cronjob=\"${local.name}\"} > ${var.backup_max_age_seconds}"
            for   = "15m"
            labels = {
              severity = "critical"
            }
            annotations = {
              summary = "No successful Vault backup in the last ${var.backup_max_age_seconds} seconds"
            }
          },
          {
            alert = "VaultBackupNeverSucceeded"
            expr  = "absent(kube_cronjob_status_last_successful_time{namespace=\"${var.vault_namespace}\", cronjob=\"${local.name}\"})"
            for   = "2h"
            labels = {
              severity = "warning"
            }
            annotations = {
              summary = "Vault backup CronJob has no recorded successful run"
            }
          },
        ]
      }]
    }
  }
}
