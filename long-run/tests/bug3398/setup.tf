provider "helm" {
  kubernetes {
    config_path = "client.config"
  }
}

provider "kubernetes" {
  config_path = "client.config"
}

variable "nfs-storage-class" {
  type = string
}

variable "nfs-storage-volume" {
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

resource "kubernetes_persistent_volume_claim" "testing-data" {
  metadata {
    name      = "testing-data"
    namespace = var.namespace
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = var.nfs-storage-class
    volume_name        = var.nfs-storage-volume
    resources {
      requests = {
        storage = "1T"
      }
    }
  }
}