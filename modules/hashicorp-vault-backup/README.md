<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | n/a |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
| <a name="provider_vault"></a> [vault](#provider\_vault) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_backup_storage"></a> [backup\_storage](#module\_backup\_storage) | ../seadweed-s3-bucket | n/a |

## Resources

| Name | Type |
|------|------|
| [kubernetes_cron_job_v1.vault_raft_backup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cron_job_v1) | resource |
| [kubernetes_manifest.backup_alerts](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_secret_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_service_account_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |
| [terraform_data.validate_backup_credentials](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [vault_kubernetes_auth_backend_role.this](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/kubernetes_auth_backend_role) | resource |
| [vault_policy.this](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_cli_version"></a> [aws\_cli\_version](#input\_aws\_cli\_version) | AWS CLI to use to backup to storage | `string` | `"2.37.8"` | no |
| <a name="input_backup"></a> [backup](#input\_backup) | Backup to S3 specifications<br/>Example:<br/>backup = {<br/>  s3\_endpoint  = "http://...:8333"<br/>  s3\_bucket    = "A BUCKET - If created with seaweed there's  no need to define"<br/>  schedule     = "0 0 0 * * *". This expression expects 6 digits.<br/>  retention\_policy = "30d" | <pre>object({<br/>    s3_endpoint = string<br/>    s3_bucket   = optional(string)<br/>    schedule    = optional(string, "0 21 * * *")<br/>  })</pre> | n/a | yes |
| <a name="input_backup_max_age_seconds"></a> [backup\_max\_age\_seconds](#input\_backup\_max\_age\_seconds) | Alert when the last successful backup is older than this many seconds. Set it to your schedule interval plus some slack (default 25h for a daily backup). | `number` | `90000` | no |
| <a name="input_cpu_limit"></a> [cpu\_limit](#input\_cpu\_limit) | CPU limit for the upload container (e.g. '200m', '1'). | `string` | `"200m"` | no |
| <a name="input_cpu_request"></a> [cpu\_request](#input\_cpu\_request) | CPU request for the upload container (e.g. '50m', '1'). | `string` | `"50m"` | no |
| <a name="input_create_backup_from_seaweedfs"></a> [create\_backup\_from\_seaweedfs](#input\_create\_backup\_from\_seaweedfs) | Name of seaweedfs cluster and namespace. If provided, bucket and credentials will be created | <pre>object({<br/>    cluster_name = string<br/>    namespace    = string<br/>  })</pre> | `null` | no |
| <a name="input_enable_prometheus_alerts"></a> [enable\_prometheus\_alerts](#input\_enable\_prometheus\_alerts) | Whether to enable metrics | `bool` | `false` | no |
| <a name="input_memory_limit"></a> [memory\_limit](#input\_memory\_limit) | Memory limit for the upload container (e.g. '256Mi', '1Gi'). | `string` | `"256Mi"` | no |
| <a name="input_memory_request"></a> [memory\_request](#input\_memory\_request) | Memory request for the upload container (e.g. '128Mi', '1Gi'). | `string` | `"128Mi"` | no |
| <a name="input_s3_credentials"></a> [s3\_credentials](#input\_s3\_credentials) | Object containing access\_key\_id and secret\_access\_key for s3 | <pre>object({<br/>    access_key_id     = string<br/>    secret_access_key = string<br/>  })</pre> | `null` | no |
| <a name="input_vault_ca_secret_key"></a> [vault\_ca\_secret\_key](#input\_vault\_ca\_secret\_key) | Key inside the Secret that contains the PEM encoded CA certificate | `string` | `"ca.crt"` | no |
| <a name="input_vault_ca_secret_name"></a> [vault\_ca\_secret\_name](#input\_vault\_ca\_secret\_name) | Name of the Kubernetes Secret (in vault\_namespace) that holds the Vault CA certificate.<br/>It is mounted as a file and exposed to the Vault CLI through VAULT\_CACERT. | `string` | n/a | yes |
| <a name="input_vault_namespace"></a> [vault\_namespace](#input\_vault\_namespace) | Name of the vault namespace where backup cronjob will be created | `string` | `"vault"` | no |
| <a name="input_vault_version"></a> [vault\_version](#input\_vault\_version) | Name of the vault namespace where backup cronjob will be created | `string` | `"1.21.2"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->