locals {
  nfs_share_labels = {
    part-of = "nfs-shares"
  }

  nfs_shares = {
    for k, v in tomap({
      movies          = var.movies_nfs_share
      music           = var.music_nfs_share
      tv-shows        = var.tvshows_nfs_share
      ebooks-comics   = var.ebooks_comics_nfs_share
      emulators-rooms = var.emulatorsrooms_nfs_share
      photos          = var.photos_nfs_share
    }) : k => v
    if v != null
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

resource "kubernetes_persistent_volume_v1" "data_volumes" {
  for_each = local.nfs_shares
  metadata {
    name = each.key
  }

  spec {
    capacity = {
      storage = each.value.size
    }

    access_modes = [each.value.access_mode]

    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = kubernetes_storage_class_v1.manual.metadata[0].name

    persistent_volume_source {
      csi {
        driver        = "nfs.csi.k8s.io"
        volume_handle = each.key
        volume_attributes = {
          server = each.value.server
          share  = each.value.path
        }
      }
    }
  }
}

# Immich config inside photos share - pre-creation of folder is necessary
resource "kubernetes_persistent_volume_v1" "immich_config" {
  count = var.photos_nfs_share != null ? 1 : 0
  metadata {
    name = "immich-config"
  }
  spec {
    capacity                         = { storage = "50Gi" }
    access_modes                     = [var.photos_nfs_share.access_mode]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = kubernetes_storage_class_v1.manual.metadata[0].name
    persistent_volume_source {
      csi {
        driver        = "nfs.csi.k8s.io"
        volume_handle = "immich-config"
        volume_attributes = {
          server = var.photos_nfs_share.server
          share  = format("%s/immich-config", var.photos_nfs_share.path)
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "calibre_library" {
  count = var.ebooks_comics_nfs_share != null ? 1 : 0

  metadata {
    name = "${local.calibre_app_name}-library"
  }

  spec {
    capacity = {
      storage = var.ebooks_comics_nfs_share.size
    }
    access_modes                     = [var.ebooks_comics_nfs_share.access_mode]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = kubernetes_storage_class_v1.manual.metadata[0].name

    persistent_volume_source {
      csi {
        driver        = "nfs.csi.k8s.io"
        volume_handle = "${local.calibre_app_name}-library"
        volume_attributes = {
          server = var.ebooks_comics_nfs_share.server
          share  = "${var.ebooks_comics_nfs_share.path}/${local.calibre_app_name}"
        }
      }
    }
  }
}

# Book converter
resource "kubernetes_persistent_volume_v1" "calibre_ingest" {
  count = var.ebooks_comics_nfs_share != null ? 1 : 0

  metadata {
    name = "${local.calibre_app_name}-ingest"
  }

  spec {
    capacity = {
      storage = "1Gi"
    }
    access_modes                     = [var.ebooks_comics_nfs_share.access_mode]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = kubernetes_storage_class_v1.manual.metadata[0].name

    persistent_volume_source {
      csi {
        driver        = "nfs.csi.k8s.io"
        volume_handle = "${local.calibre_app_name}-ingest"
        volume_attributes = {
          server = var.ebooks_comics_nfs_share.server
          share  = "${var.ebooks_comics_nfs_share.path}/${local.calibre_app_name}/CONVERT"
        }
      }
    }
  }
}
