provider "helm" {
  kubernetes {
    config_path = "client.config"
  }
}

provider "kubernetes" {
  config_path = "client.config"
}

variable "nfs-server" {
  type = string
}

variable "nfs-path" {
  type = string
}

variable "fluent-bit-config" {
  type = string
}

variable "namespace" {
  type = string
}

data "local_file" "fluent-bit-config" {
  filename = basename(var.fluent-bit-config)
}

resource "helm_release" "fluent-bit" {
  name       = "fluent-bit"
  namespace  = var.namespace
  force_update = true
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  values = [data.local_file.fluent-bit-config.content]
  depends_on = [kubernetes_persistent_volume_claim.testing-data]
  wait = true
}

resource "kubernetes_storage_class" "nfs" {
  metadata {
    name = "filestore"
  }
  reclaim_policy      = "Retain"
  storage_provisioner = "nfs"
}

resource "kubernetes_persistent_volume" "nfs-volume" {
  metadata {
    name = "nfs-volume"
  }
  spec {
    capacity = {
      storage = "1T"
    }
    storage_class_name = kubernetes_storage_class.nfs.metadata[0].name
    access_modes       = ["ReadWriteMany"]
    persistent_volume_source {
      nfs {
        server = var.nfs-server
        path   = var.nfs-path
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "testing-data" {
  metadata {
    name      = "testing-data"
    namespace = var.namespace
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = kubernetes_storage_class.nfs.metadata[0].name
    volume_name        = kubernetes_persistent_volume.nfs-volume.metadata[0].name
    resources {
      requests = {
        storage = "1T"
      }
    }
  }
}