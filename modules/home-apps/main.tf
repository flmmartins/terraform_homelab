locals {
  nfs_share_labels = {
    part-of = "nfs-shares"
  }
}

# Necessary to create because otherwise apps would try to use dynamic provisioning
resource "kubernetes_storage_class_v1" "manual" {
  metadata {
    name = "manual"
  }

  storage_provisioner    = "kubernetes.io/no-provisioner"
  volume_binding_mode    = "WaitForFirstConsumer"
  reclaim_policy         = "Retain"
  allow_volume_expansion = true
}
