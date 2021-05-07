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
  depends_on = [kubernetes_persistent_volume_claim.testing-data, kubernetes_deployment.benchmark-tool]
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


resource "kubernetes_deployment" "benchmark-tool" {
  metadata {
    name      = "benchmark-tool"
    namespace = var.namespace
    labels = {
      mylabel = "benchmark-tool"
    }
  }

  spec {
    replicas = 1

    template {
      metadata {
        labels = {
          mylabel = "benchmark-tool"
        }
      }

      spec {
        container {
          image = "fluentbitdev/fluent-bit-ci:benchmark"
          name  = "benchmark-tool"
          args = ["--log-size-in-bytes 1000", "--log-rate 200000", "--log-agent-input-type tail", "--tail-file-path /data/test.log"]
          resources {
            limits = {
              cpu    = "2000m"
              memory = "2048Mi"
            }
            requests = {
              cpu    = "2000m"
              memory = "1024Mi"
            }
          }

          volume_mount {
            mount_path = "/data"
            name       = "nfs-data"
          }
        }
        volume {
          name = "nfs-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.testing-data.metadata.0.name
          }
        }
      }
    }
  }
}
