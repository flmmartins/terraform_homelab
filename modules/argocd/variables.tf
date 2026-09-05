variable "chart_version" {
  description = "Argo CD Chart Version from https://github.com/argoproj/argo-helm/releases"
  type        = string
  default     = "10.7.1"
}

variable "enable_https_backend" {
  description = "If true, argocd-server terminates TLS itself and the Gateway re-encrypts to it via BackendTLSPolicy (requires certificate_issuer + internal CA configmap). If false, the Gateway sends plain HTTP to the backend."
  type        = bool
  default     = false
}

variable "certificate_issuer" {
  description = "Cert Manager ClusterIssuer used to issue argocd-server's own TLS certificate (required when enable_https_backend = true)"
  type = object({
    name                   = string
    ca_configmap_namespace = string
    ca_configmap           = string
  })
  default = null
}

variable "url" {
  type        = string
  description = "Argo CD UI/API URL"
}

variable "gateway" {
  description = "Gateway to use for the app"
  type = object({
    name      = string
    namespace = string
  })
}

variable "priority_class" {
  description = "Priority class name to assign to Argo CD components"
  type        = string
  default     = null
}

# =============================================================================
# HA topology
# =============================================================================
variable "server_replicas" {
  description = "Number of argocd-server replicas"
  type        = number
  default     = 2
}

variable "repo_server_replicas" {
  description = "Number of argocd-repo-server replicas"
  type        = number
  default     = 2
}

variable "applicationset_controller_replicas" {
  description = "Number of applicationset-controller replicas"
  type        = number
  default     = 2
}

variable "controller_replicas" {
  description = "Application-controller shard count. Only useful if you register additional external clusters — with a single in-cluster destination, 1 shard is correct and >1 gives no benefit."
  type        = number
  default     = 1
}

variable "redis_ha_enabled" {
  description = "Use the 3-node redis-ha subchart instead of a single redis pod. NOT recommended with only 2 worker nodes: redis-ha defaults to hardAntiAffinity across 3 nodes, so the 3rd pod will be stuck Pending. Redis here is only a cache (state lives in CRDs), so a single instance is usually the right tradeoff on this hardware."
  type        = bool
  default     = false
}

# =============================================================================
# Resource Variables
# =============================================================================
# server
variable "server_cpu_request" {
  type    = string
  default = "50m"
}
variable "server_memory_request" {
  type    = string
  default = "64Mi"
}
variable "server_cpu_limit" {
  type    = string
  default = "200m"
}
variable "server_memory_limit" {
  type    = string
  default = "128Mi"
}

# repo-server
variable "repo_server_cpu_request" {
  type    = string
  default = "50m"
}
variable "repo_server_memory_request" {
  type    = string
  default = "128Mi"
}
variable "repo_server_cpu_limit" {
  type    = string
  default = "300m"
}
variable "repo_server_memory_limit" {
  type    = string
  default = "256Mi"
}

# application-controller
variable "controller_cpu_request" {
  type    = string
  default = "100m"
}
variable "controller_memory_request" {
  type    = string
  default = "256Mi"
}
variable "controller_cpu_limit" {
  type    = string
  default = "500m"
}
variable "controller_memory_limit" {
  type    = string
  default = "512Mi"
}

# applicationset-controller
variable "applicationset_controller_cpu_request" {
  type    = string
  default = "25m"
}
variable "applicationset_controller_memory_request" {
  type    = string
  default = "64Mi"
}
variable "applicationset_controller_cpu_limit" {
  type    = string
  default = "100m"
}
variable "applicationset_controller_memory_limit" {
  type    = string
  default = "128Mi"
}

# notifications-controller (single instance by design, not part of HA surface)
variable "notifications_controller_cpu_request" {
  type    = string
  default = "25m"
}
variable "notifications_controller_memory_request" {
  type    = string
  default = "64Mi"
}
variable "notifications_controller_cpu_limit" {
  type    = string
  default = "100m"
}
variable "notifications_controller_memory_limit" {
  type    = string
  default = "128Mi"
}

# redis (single instance, default path)
variable "redis_cpu_request" {
  type    = string
  default = "50m"
}
variable "redis_memory_request" {
  type    = string
  default = "64Mi"
}
variable "redis_cpu_limit" {
  type    = string
  default = "150m"
}
variable "redis_memory_limit" {
  type    = string
  default = "128Mi"
}

# redis-ha (only used if redis_ha_enabled = true)
variable "redis_ha_haproxy_cpu_request" {
  type    = string
  default = "25m"
}
variable "redis_ha_haproxy_memory_request" {
  type    = string
  default = "32Mi"
}
variable "redis_ha_haproxy_cpu_limit" {
  type    = string
  default = "100m"
}
variable "redis_ha_haproxy_memory_limit" {
  type    = string
  default = "64Mi"
}
variable "redis_ha_server_cpu_request" {
  type    = string
  default = "50m"
}
variable "redis_ha_server_memory_request" {
  type    = string
  default = "64Mi"
}
variable "redis_ha_server_cpu_limit" {
  type    = string
  default = "150m"
}
variable "redis_ha_server_memory_limit" {
  type    = string
  default = "128Mi"
}
