
variable "backup" {
  description = <<-EOT
    Backup to S3 specifications
    Example:
    backup = {
      s3_endpoint  = "http://...:8333"
      s3_bucket    = "A BUCKET - If created with seaweed there's  no need to define"
      schedule     = "0 0 0 * * *". This expression expects 6 digits.
  EOT
  type = object({
    s3_endpoint = string
    s3_bucket   = optional(string)
    schedule    = optional(string, "0 21 * * *")
  })
}

variable "create_backup_from_seaweedfs" {
  description = "Name of seaweedfs cluster and namespace. If provided, bucket and credentials will be created"
  type = object({
    cluster_name   = string
    namespace      = string
    retention_days = optional(number, 30)
  })
  default = null
}

variable "s3_credentials" {
  description = "Object containing access_key_id and secret_access_key for s3"
  type = object({
    access_key_id     = string
    secret_access_key = string
  })
  default   = null
  sensitive = true
}

variable "vault_namespace" {
  description = "Name of the vault namespace where backup cronjob will be created"
  default     = "vault"
}

variable "vault_version" {
  description = "Name of the vault namespace where backup cronjob will be created"
  default     = "2.0.4"
}

variable "aws_cli_version" {
  description = "AWS CLI to use to backup to storage"
  default     = "2.37.8"
}

variable "vault_ca_secret_name" {
  description = <<-EOT
    Name of the Kubernetes Secret (in vault_namespace) that holds the Vault CA certificate.
    It is mounted as a file and exposed to the Vault CLI through VAULT_CACERT.
  EOT
  type        = string
}

variable "vault_ca_secret_key" {
  description = "Key inside the Secret that contains the PEM encoded CA certificate"
  type        = string
  default     = "ca.crt"
}

# =============================================================================
# Resource Variables
# =============================================================================

variable "cpu_request" {
  description = "CPU request for the upload container (e.g. '50m', '1')."
  type        = string
  default     = "50m"
}

variable "memory_request" {
  description = "Memory request for the upload container (e.g. '128Mi', '1Gi')."
  type        = string
  default     = "128Mi"
}

variable "cpu_limit" {
  description = "CPU limit for the upload container (e.g. '200m', '1')."
  type        = string
  default     = "200m"
}

variable "memory_limit" {
  description = "Memory limit for the upload container (e.g. '256Mi', '1Gi')."
  type        = string
  default     = "256Mi"
}

variable "enable_prometheus_alerts" {
  description = "Whether to enable metrics"
  type        = bool
  default     = false
}

variable "backup_max_age_seconds" {
  description = "Alert when the last successful backup is older than this many seconds. Set it to your schedule interval plus some slack (default 25h for a daily backup)."
  type        = number
  default     = 90000
}
