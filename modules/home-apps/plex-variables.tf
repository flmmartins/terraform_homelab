variable "plex_chart_version" {
  description = "Plex Version"
  default     = "1.6.0"
}

variable "plex_exporter_version" {
  description = "Plex Version"
  default     = "v2.2.11"
}

variable "plex_gateway_tcp_listener" {
  description = "Name of the listener that will be used by plex to connect via IP"
  type        = string
}

variable "plex_ip" {
  description = "Plex needs load balancer IP to ADVERTISE_IP configuration. This can be a load balancer IP."
  type        = string
}

variable "plex_config_storage_class" {
  type        = string
  description = "Name of the storage class for plex config database - has to be local"
}

variable "plex_config_path" {
  type        = string
  description = "Path inside the local volume. It has to be pre-created"
}

variable "plex_config_size" {
  type        = string
  description = "Size of the local volume"
  default     = "5Gi"
}


variable "plex_node" {
  type        = string
  description = "Plex node pinning due to local storage"
}


variable "plex_vault_token" {
  description = <<-EOT
    Vault configuration to read the Plex API token from, used by the plex-exporter
    sidecar for monitoring. If null, you need to manually create the secret for monitoring

    Example:
    plex_vault_token = {
      secret_path   = "secret/plex"
      vault_address = "https://vault.vault:8200"

      # Optional overrides (these are the defaults):
      vault_csi_ca_cert_path = "/vault/tls/ca.crt"
      token_field            = "password"
    }

    To obtain the token itself, see /config/Library/Application Support/Plex Media Server/Preferences.xml
    (PlexOnlineToken attribute) inside the running Plex pod
  EOT
  type = object({
    secret_path            = string
    vault_address          = string
    vault_csi_ca_cert_path = optional(string, "/vault/tls/ca.crt")
    token_field            = optional(string, "password")
  })
  default = null
}
