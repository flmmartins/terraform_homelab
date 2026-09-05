# Setting argo secret with a password of choice

When trying to create the secret that sets the admin password it was observed that the secret contains several fields, not only password, like the modification time of the secret an auto generated server.secretkey. Therefore we let it generate the admin password and fetch after initialization:

```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | n/a |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.this](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_config_map_v1.ca](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_manifest.certificate_server](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_config_map_v1.ca](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/config_map_v1) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_applicationset_controller_cpu_limit"></a> [applicationset\_controller\_cpu\_limit](#input\_applicationset\_controller\_cpu\_limit) | n/a | `string` | `"100m"` | no |
| <a name="input_applicationset_controller_cpu_request"></a> [applicationset\_controller\_cpu\_request](#input\_applicationset\_controller\_cpu\_request) | applicationset-controller | `string` | `"25m"` | no |
| <a name="input_applicationset_controller_memory_limit"></a> [applicationset\_controller\_memory\_limit](#input\_applicationset\_controller\_memory\_limit) | n/a | `string` | `"128Mi"` | no |
| <a name="input_applicationset_controller_memory_request"></a> [applicationset\_controller\_memory\_request](#input\_applicationset\_controller\_memory\_request) | n/a | `string` | `"64Mi"` | no |
| <a name="input_applicationset_controller_replicas"></a> [applicationset\_controller\_replicas](#input\_applicationset\_controller\_replicas) | Number of applicationset-controller replicas | `number` | `2` | no |
| <a name="input_certificate_issuer"></a> [certificate\_issuer](#input\_certificate\_issuer) | Cert Manager ClusterIssuer used to issue argocd-server's own TLS certificate (required when enable\_https\_backend = true) | <pre>object({<br/>    name                   = string<br/>    ca_configmap_namespace = string<br/>    ca_configmap           = string<br/>  })</pre> | `null` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Argo CD Chart Version from https://github.com/argoproj/argo-helm/releases | `string` | `"10.7.1"` | no |
| <a name="input_controller_cpu_limit"></a> [controller\_cpu\_limit](#input\_controller\_cpu\_limit) | n/a | `string` | `"500m"` | no |
| <a name="input_controller_cpu_request"></a> [controller\_cpu\_request](#input\_controller\_cpu\_request) | application-controller | `string` | `"100m"` | no |
| <a name="input_controller_memory_limit"></a> [controller\_memory\_limit](#input\_controller\_memory\_limit) | n/a | `string` | `"512Mi"` | no |
| <a name="input_controller_memory_request"></a> [controller\_memory\_request](#input\_controller\_memory\_request) | n/a | `string` | `"256Mi"` | no |
| <a name="input_controller_replicas"></a> [controller\_replicas](#input\_controller\_replicas) | Application-controller shard count. Only useful if you register additional external clusters — with a single in-cluster destination, 1 shard is correct and >1 gives no benefit. | `number` | `1` | no |
| <a name="input_enable_https_backend"></a> [enable\_https\_backend](#input\_enable\_https\_backend) | If true, argocd-server terminates TLS itself and the Gateway re-encrypts to it via BackendTLSPolicy (requires certificate\_issuer + internal CA configmap). If false, the Gateway sends plain HTTP to the backend. | `bool` | `false` | no |
| <a name="input_gateway"></a> [gateway](#input\_gateway) | Gateway to use for the app | <pre>object({<br/>    name      = string<br/>    namespace = string<br/>  })</pre> | n/a | yes |
| <a name="input_notifications_controller_cpu_limit"></a> [notifications\_controller\_cpu\_limit](#input\_notifications\_controller\_cpu\_limit) | n/a | `string` | `"100m"` | no |
| <a name="input_notifications_controller_cpu_request"></a> [notifications\_controller\_cpu\_request](#input\_notifications\_controller\_cpu\_request) | notifications-controller (single instance by design, not part of HA surface) | `string` | `"25m"` | no |
| <a name="input_notifications_controller_memory_limit"></a> [notifications\_controller\_memory\_limit](#input\_notifications\_controller\_memory\_limit) | n/a | `string` | `"128Mi"` | no |
| <a name="input_notifications_controller_memory_request"></a> [notifications\_controller\_memory\_request](#input\_notifications\_controller\_memory\_request) | n/a | `string` | `"64Mi"` | no |
| <a name="input_priority_class"></a> [priority\_class](#input\_priority\_class) | Priority class name to assign to Argo CD components | `string` | `null` | no |
| <a name="input_redis_cpu_limit"></a> [redis\_cpu\_limit](#input\_redis\_cpu\_limit) | n/a | `string` | `"150m"` | no |
| <a name="input_redis_cpu_request"></a> [redis\_cpu\_request](#input\_redis\_cpu\_request) | redis (single instance, default path) | `string` | `"50m"` | no |
| <a name="input_redis_ha_enabled"></a> [redis\_ha\_enabled](#input\_redis\_ha\_enabled) | Use the 3-node redis-ha subchart instead of a single redis pod. NOT recommended with only 2 worker nodes: redis-ha defaults to hardAntiAffinity across 3 nodes, so the 3rd pod will be stuck Pending. Redis here is only a cache (state lives in CRDs), so a single instance is usually the right tradeoff on this hardware. | `bool` | `false` | no |
| <a name="input_redis_ha_haproxy_cpu_limit"></a> [redis\_ha\_haproxy\_cpu\_limit](#input\_redis\_ha\_haproxy\_cpu\_limit) | n/a | `string` | `"100m"` | no |
| <a name="input_redis_ha_haproxy_cpu_request"></a> [redis\_ha\_haproxy\_cpu\_request](#input\_redis\_ha\_haproxy\_cpu\_request) | redis-ha (only used if redis\_ha\_enabled = true) | `string` | `"25m"` | no |
| <a name="input_redis_ha_haproxy_memory_limit"></a> [redis\_ha\_haproxy\_memory\_limit](#input\_redis\_ha\_haproxy\_memory\_limit) | n/a | `string` | `"64Mi"` | no |
| <a name="input_redis_ha_haproxy_memory_request"></a> [redis\_ha\_haproxy\_memory\_request](#input\_redis\_ha\_haproxy\_memory\_request) | n/a | `string` | `"32Mi"` | no |
| <a name="input_redis_ha_server_cpu_limit"></a> [redis\_ha\_server\_cpu\_limit](#input\_redis\_ha\_server\_cpu\_limit) | n/a | `string` | `"150m"` | no |
| <a name="input_redis_ha_server_cpu_request"></a> [redis\_ha\_server\_cpu\_request](#input\_redis\_ha\_server\_cpu\_request) | n/a | `string` | `"50m"` | no |
| <a name="input_redis_ha_server_memory_limit"></a> [redis\_ha\_server\_memory\_limit](#input\_redis\_ha\_server\_memory\_limit) | n/a | `string` | `"128Mi"` | no |
| <a name="input_redis_ha_server_memory_request"></a> [redis\_ha\_server\_memory\_request](#input\_redis\_ha\_server\_memory\_request) | n/a | `string` | `"64Mi"` | no |
| <a name="input_redis_memory_limit"></a> [redis\_memory\_limit](#input\_redis\_memory\_limit) | n/a | `string` | `"128Mi"` | no |
| <a name="input_redis_memory_request"></a> [redis\_memory\_request](#input\_redis\_memory\_request) | n/a | `string` | `"64Mi"` | no |
| <a name="input_repo_server_cpu_limit"></a> [repo\_server\_cpu\_limit](#input\_repo\_server\_cpu\_limit) | n/a | `string` | `"300m"` | no |
| <a name="input_repo_server_cpu_request"></a> [repo\_server\_cpu\_request](#input\_repo\_server\_cpu\_request) | repo-server | `string` | `"50m"` | no |
| <a name="input_repo_server_memory_limit"></a> [repo\_server\_memory\_limit](#input\_repo\_server\_memory\_limit) | n/a | `string` | `"256Mi"` | no |
| <a name="input_repo_server_memory_request"></a> [repo\_server\_memory\_request](#input\_repo\_server\_memory\_request) | n/a | `string` | `"128Mi"` | no |
| <a name="input_repo_server_replicas"></a> [repo\_server\_replicas](#input\_repo\_server\_replicas) | Number of argocd-repo-server replicas | `number` | `2` | no |
| <a name="input_server_cpu_limit"></a> [server\_cpu\_limit](#input\_server\_cpu\_limit) | n/a | `string` | `"200m"` | no |
| <a name="input_server_cpu_request"></a> [server\_cpu\_request](#input\_server\_cpu\_request) | ============================================================================= Resource Variables ============================================================================= server | `string` | `"50m"` | no |
| <a name="input_server_memory_limit"></a> [server\_memory\_limit](#input\_server\_memory\_limit) | n/a | `string` | `"128Mi"` | no |
| <a name="input_server_memory_request"></a> [server\_memory\_request](#input\_server\_memory\_request) | n/a | `string` | `"64Mi"` | no |
| <a name="input_server_replicas"></a> [server\_replicas](#input\_server\_replicas) | Number of argocd-server replicas | `number` | `2` | no |
| <a name="input_url"></a> [url](#input\_url) | Argo CD UI/API URL | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->