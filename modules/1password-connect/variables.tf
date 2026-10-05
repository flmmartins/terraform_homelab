variable "chart_version" {
  description = "1password Connect Chart Version. Versions can be found in https://github.com/1Password/connect-helm-charts/releases"
  default     = "2.4.1"
}

variable "priority_class" {
  description = "Describe the priority class the cluster pods should be in"
  type        = string
  default     = ""
}

variable "credentials_json_base64" {
  description = "1password Credentials File json encoded in base64"
  type        = string
  sensitive   = true
}
