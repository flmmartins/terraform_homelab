variable "provider_api" {
  description = "S3 Provider url"
  default     = "seaweed.seaweedfs.com/v1"
}

variable "seaweedfs" {
  description = "Name of seaweedfs cluster and namespace"
  type = object({
    cluster_name = string
    namespace    = string
  })
}

variable "application" {
  description = "Name and namespace of the application allowed to interact with bucket"
  type = object({
    name      = string
    namespace = string
  })
}

variable "access_key_field" {
  description = "The secret field that should contain the access key id"
  default     = "accessKey"
}

variable "secret_key_field" {
  description = "The secret field that should contain the secret key"
  default     = "secretKey"
}

variable "retention_days" {
  description = <<-EOT
    Delete objects after this many days (SeaweedFS volume TTL).
    If null, objects are kept forever. Max 255 (SeaweedFS stores TTL count in one byte).
    Example: retention_days = 30
  EOT
  type        = number
  default     = null

  validation {
    condition     = var.retention_days == null || (var.retention_days > 0 && var.retention_days <= 255)
    error_message = "retention_days must be between 1 and 255 when set."
  }
}

variable "versioning" {
  description = <<-EOT
    Bucket versioning: Off, Enabled or Suspended. If null, the field is not set and the operator default applies which is usually disabled.
    Example: versioning = "Enabled"
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.versioning == null || contains(["Off", "Enabled", "Suspended"], var.versioning)
    error_message = "versioning must be one of Off, Enabled or Suspended."
  }
}

variable "object_lock" {
  description = <<-EOT
    Enable S3 Object Lock on the bucket. Requires versioning = "Enabled".
    This should be decided at bucket creation: on AWS it can't be turned off later and SeaweedFS follows the same semantics.
    Example: object_lock = true
  EOT
  type        = bool
  default     = false

  validation {
    condition     = !var.object_lock || var.versioning == "Enabled"
    error_message = "object_lock requires versioning to be \"Enabled\"."
  }
}
