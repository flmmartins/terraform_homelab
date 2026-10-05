variable "immich_chart_version" {
  description = "Photos Processing App Version. Versions can be found in https://github.com/immich-app/immich-charts/releases"
  default     = "0.13.2"
}

variable "immich_album_creator_version" {
  description = "Version of the immich-folder-album-creator image. According to github it has to be latest"
  type        = string
  default     = "latest"
}

variable "immich_album_creator_schedule" {
  description = "Cron schedule for the album creator job"
  type        = string
  default     = "0 4 * * *"
}

variable "immich_api_key_vault" {
  description = <<-EOT
    Vault Agent configuration to inject the Immich API key into the album creator job.
    The API key must be stored in Vault and will be injected as an environment variable.
    In order for key to be fetched we require the name of the vault ca configmap and it will be copy to immich namespace

    Example:
    immich_api_key_vault = {
      secret_path   = "op/vaults/<vault-id>/items/immich"
      vault_address = "https://vault.vaultnamespace:8200"
      api_key_field = "apiKey"
      vault_ca_configmap_name      = "vault-ca"
      vault_ca_configmap_namespace = "vault"
    }
  EOT
  type = object({
    secret_path                  = string
    vault_csi_ca_cert_path       = optional(string, "/vault/tls/ca.crt")
    api_key_field                = optional(string, "immich-folder-album-creator")
    vault_ca_configmap_name      = string
    vault_ca_configmap_namespace = string
  })
  default = null
}

variable "immich_database" {
  description = "Database spects for immich"
  type = object({
    server                  = string
    database_name           = string
    credentials_secret_name = string
  })
}
