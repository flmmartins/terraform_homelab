terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

locals {
  name = "argocd"
  labels = {
    part-of = "gitops"
  }
  server_name = "${local.name}-server"
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name   = local.name
    labels = local.labels
  }
}

# ---------------------------------------------------------------------------
# TLS for argocd-server (Gateway re-encrypts to backend when enabled)
# ---------------------------------------------------------------------------
resource "kubernetes_manifest" "certificate_server" {
  count = var.enable_https_backend == true ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "argocd-server-tls"
      namespace = kubernetes_namespace_v1.this.metadata[0].name
      labels    = merge(local.labels, { component = "certificate" })
    }
    spec = {
      secretName = "argocd-server-tls" # Argo CD auto-mounts this exact secret name if present
      commonName = var.url
      dnsNames = [
        var.url,
        local.server_name,
        "${local.server_name}.${kubernetes_namespace_v1.this.metadata[0].name}",
        "${local.server_name}.${kubernetes_namespace_v1.this.metadata[0].name}.svc",
        "${local.server_name}.${kubernetes_namespace_v1.this.metadata[0].name}.svc.cluster.local",
      ]
      usages = ["server auth"]
      issuerRef = {
        name  = var.certificate_issuer.name
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
    }
  }
}

# BackendTLS Policy requires the CA to be in configmap
data "kubernetes_config_map_v1" "ca" {
  count = var.enable_https_backend == true ? 1 : 0

  metadata {
    name      = var.certificate_issuer.ca_configmap
    namespace = var.certificate_issuer.ca_configmap_namespace
  }
}

resource "kubernetes_config_map_v1" "ca" {
  count = var.enable_https_backend == true ? 1 : 0

  metadata {
    name      = "${local.name}-ca"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = merge(local.labels, {
      component = "certificate"
    })
  }

  data = {
    "ca.crt" = data.kubernetes_config_map_v1.ca[0].data["ca.crt"]
  }
}

# ---------------------------------------------------------------------------
# Argo CD itself
# ---------------------------------------------------------------------------
# This chart has subcharts (redis / redis-ha)
resource "helm_release" "this" {
  name        = local.name
  namespace   = kubernetes_namespace_v1.this.metadata[0].name
  repository  = "https://argoproj.github.io/argo-helm"
  version     = var.chart_version
  chart       = "argo-cd"
  max_history = 10
  values = [
    <<-EOF
    global:
      additionalLabels: ${jsonencode(local.labels)}
    %{~if var.priority_class != null~}
      priorityClassName: ${var.priority_class}
    %{~endif~}

    configs:
      params:
        server.insecure: ${!var.enable_https_backend}

    # ---------------------------------------------------------------------
    # Server — stateless, HA-able
    # ---------------------------------------------------------------------
    server:
      replicas: ${var.server_replicas}
      podLabels:
        component: server
      resources:
        requests:
          cpu: ${var.server_cpu_request}
          memory: ${var.server_memory_request}
        limits:
          cpu: ${var.server_cpu_limit}
          memory: ${var.server_memory_limit}
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: component
                  operator: In
                  values:
                  - server
              topologyKey: kubernetes.io/hostname
      httproute:
        enabled: true
        labels: ${jsonencode(merge(local.labels, { component = "httproute" }))}
        parentRefs:
        - name: ${var.gateway.name}
          namespace: ${var.gateway.namespace}
        hostnames:
        - ${var.url}
    %{~if var.enable_https_backend == true~}
      backendTLSPolicy:
        enabled: true
        labels: ${jsonencode(merge(local.labels, { component = "backendtlspolicy" }))}
        targetRefs:
        - group: ""
          kind: Service
          name: ${local.server_name}
        validation:
          hostname: ${var.url}
          caCertificateRefs:
          - group: ""
            kind: ConfigMap
            name: ${local.name}-ca
    %{~endif~}

    # ---------------------------------------------------------------------
    # Repo Server — stateless, HA-able
    # ---------------------------------------------------------------------
    repoServer:
      replicas: ${var.repo_server_replicas}
      podLabels:
        component: repo-server
      resources:
        requests:
          cpu: ${var.repo_server_cpu_request}
          memory: ${var.repo_server_memory_request}
        limits:
          cpu: ${var.repo_server_cpu_limit}
          memory: ${var.repo_server_memory_limit}
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: component
                  operator: In
                  values:
                  - repo-server
              topologyKey: kubernetes.io/hostname

    # ---------------------------------------------------------------------
    # Application Controller — sharded, not simple replica-based HA
    # ---------------------------------------------------------------------
    controller:
      replicas: ${var.controller_replicas}
      podLabels:
        component: controller
      resources:
        requests:
          cpu: ${var.controller_cpu_request}
          memory: ${var.controller_memory_request}
        limits:
          cpu: ${var.controller_cpu_limit}
          memory: ${var.controller_memory_limit}

    # ---------------------------------------------------------------------
    # ApplicationSet Controller — stateless, HA-able
    # ---------------------------------------------------------------------
    applicationSet:
      replicas: ${var.applicationset_controller_replicas}
      podLabels:
        component: applicationset-controller
      resources:
        requests:
          cpu: ${var.applicationset_controller_cpu_request}
          memory: ${var.applicationset_controller_memory_request}
        limits:
          cpu: ${var.applicationset_controller_cpu_limit}
          memory: ${var.applicationset_controller_memory_limit}
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: component
                  operator: In
                  values:
                  - applicationset-controller
              topologyKey: kubernetes.io/hostname

    # ---------------------------------------------------------------------
    # Notifications — single instance by design
    # ---------------------------------------------------------------------
    notifications:
      enabled: true
      resources:
        requests:
          cpu: ${var.notifications_controller_cpu_request}
          memory: ${var.notifications_controller_memory_request}
        limits:
          cpu: ${var.notifications_controller_cpu_limit}
          memory: ${var.notifications_controller_memory_limit}

    # No SSO configured — skip Dex to save memory. Enable + configure OIDC later.
    dex:
      enabled: false

    # ---------------------------------------------------------------------
    # Redis — see module README for why this defaults to single-instance
    # ---------------------------------------------------------------------
    redis:
      enabled: ${!var.redis_ha_enabled}
      resources:
        requests:
          cpu: ${var.redis_cpu_request}
          memory: ${var.redis_memory_request}
        limits:
          cpu: ${var.redis_cpu_limit}
          memory: ${var.redis_memory_limit}

    redis-ha:
      enabled: ${var.redis_ha_enabled}
      hardAntiAffinity: false # required=false; with 2 workers hard antiaffinity leaves 1 pod Pending
      haproxy:
        resources:
          requests:
            cpu: ${var.redis_ha_haproxy_cpu_request}
            memory: ${var.redis_ha_haproxy_memory_request}
          limits:
            cpu: ${var.redis_ha_haproxy_cpu_limit}
            memory: ${var.redis_ha_haproxy_memory_limit}
      resources:
        requests:
          cpu: ${var.redis_ha_server_cpu_request}
          memory: ${var.redis_ha_server_memory_request}
        limits:
          cpu: ${var.redis_ha_server_cpu_limit}
          memory: ${var.redis_ha_server_memory_limit}
    EOF
  ]
}
