<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_manifest.allow_app_create_seaweedfs_secret](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.bucket](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.s3_credentials](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.s3_identity](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.s3_policy](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.s3_policy_binding](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_secret_v1.s3_credentials_placeholder](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_key_field"></a> [access\_key\_field](#input\_access\_key\_field) | The secret field that should contain the access key id | `string` | `"accessKey"` | no |
| <a name="input_application"></a> [application](#input\_application) | Name and namespace of the application allowed to interact with bucket | <pre>object({<br/>    name      = string<br/>    namespace = string<br/>  })</pre> | n/a | yes |
| <a name="input_object_lock"></a> [object\_lock](#input\_object\_lock) | Enable S3 Object Lock on the bucket. Requires versioning = "Enabled".<br/>This should be decided at bucket creation: on AWS it can't be turned off later and SeaweedFS follows the same semantics.<br/>Example: object\_lock = true | `bool` | `false` | no |
| <a name="input_provider_api"></a> [provider\_api](#input\_provider\_api) | S3 Provider url | `string` | `"seaweed.seaweedfs.com/v1"` | no |
| <a name="input_retention_days"></a> [retention\_days](#input\_retention\_days) | Delete objects after this many days (SeaweedFS volume TTL).<br/>If null, objects are kept forever. Max 255 (SeaweedFS stores TTL count in one byte).<br/>Example: retention\_days = 30 | `number` | `null` | no |
| <a name="input_seaweedfs"></a> [seaweedfs](#input\_seaweedfs) | Name of seaweedfs cluster and namespace | <pre>object({<br/>    cluster_name = string<br/>    namespace    = string<br/>  })</pre> | n/a | yes |
| <a name="input_secret_key_field"></a> [secret\_key\_field](#input\_secret\_key\_field) | The secret field that should contain the secret key | `string` | `"secretKey"` | no |
| <a name="input_versioning"></a> [versioning](#input\_versioning) | Bucket versioning: Off, Enabled or Suspended. If null, the field is not set and the operator default applies which is usually disabled.<br/>Example: versioning = "Enabled" | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket"></a> [bucket](#output\_bucket) | Name of the created bucket |
| <a name="output_secret_fields"></a> [secret\_fields](#output\_secret\_fields) | Name of the keys inside kubernetes secret |
| <a name="output_secret_name"></a> [secret\_name](#output\_secret\_name) | Name of the secret in kubernetes containing s3 credentials |
<!-- END_TF_DOCS -->