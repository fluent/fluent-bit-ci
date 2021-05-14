provider "helm" {
  kubernetes {
    config_path = "client.config"
  }
}

provider "kubernetes" {
  config_path = "client.config"
}

variable "prometheus-config" {
  type = string
}

variable "fluent-bit-config" {
  type = string
}

variable "gcp-disk-id" {
  type = string
}

variable "gcp-sa-key" {
  type = string
}

variable "namespace" {
  type = string
}

data "local_file" "fluent-bit-config" {
  filename = basename(var.fluent-bit-config)
}

data "local_file" "prometheus-config" {
  filename = basename(var.prometheus-config)
}

data "local_file" "gcp_sa_key" {
  filename = basename(var.gcp-sa-key)
}

resource "kubernetes_secret" "service_account_data" {
  metadata {
    name      = "google-service-account-sa-key"
    namespace = var.namespace
  }
  data = {
    "google_service_credentials.json" = data.local_file.gcp_sa_key.content
  }
}

resource "helm_release" "fluent-bit" {
  name       = "fluent-bit"
  namespace  = var.namespace
  force_update = true
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  values = [data.local_file.fluent-bit-config.content]
  depends_on = [kubernetes_secret.service_account_data]
  #depends_on = [kubernetes_persistent_volume_claim.testing-data, kubernetes_deployment.benchmark-tool]
  wait = true
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = var.namespace
  values = [data.local_file.prometheus-config.content]
}

//
//resource "kubernetes_storage_class" "nfs" {
//  metadata {
//    name = "nfs-${var.namespace}"
//  }
//  reclaim_policy      = "Retain"
//  storage_provisioner = "nfs"
//}
//
//resource "kubernetes_persistent_volume" "nfs-volume" {
//  metadata {
//    name = "nfs-volume-${var.namespace}"
//  }
//  spec {
//    capacity = {
//      storage = "1T"
//    }
//
//    storage_class_name = kubernetes_storage_class.nfs.metadata.0.name
//    access_modes       = ["ReadWriteMany"]
//    persistent_volume_source {
//      nfs {
//        server = var.nfs-server
//        path   = var.nfs-path
//      }
//    }
//  }
//}
//
//
resource "kubernetes_storage_class" "testing_storage" {
  metadata {
    name  = "fast-${random_id.disk.hex}"
  }

  storage_provisioner = "kubernetes.io/gce-pd"

  parameters = {
    type = "pd-ssd"
  }

  allow_volume_expansion = true
}

resource "kubernetes_persistent_volume" "testing_storage" {
  metadata {
    name  = "testing-data-volume-${random_id.disk.hex}"
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    capacity = {
      storage = "300Gi"
    }

    persistent_volume_reclaim_policy  = "Retain"
    storage_class_name                = "fast-${random_id.disk.hex}"

    persistent_volume_source {
      gce_persistent_disk {
        pd_name = var.gcp-disk-id
        fs_type = "ext4"
      }
    }
  }

  depends_on = [kubernetes_storage_class.testing_storage]
}

resource "kubernetes_persistent_volume_claim" "testing_storage" {
  metadata {
    name      = "testing-data-claim"
    namespace = var.namespace

    annotations = {
      "volume.beta.kubernetes.io/storage-class" = "fast-${random_id.disk.hex}"
    }
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "300Gi"
      }
    }
  }

  depends_on = [kubernetes_persistent_volume.testing_storage]
}

resource "random_id" "disk" {
  byte_length = 4
}
//
//resource "kubernetes_persistent_volume" "testing-data-volume" {
//  metadata {
//    name = "testing-data-volume-${random_id.disk.hex}"
//  }
//  spec {
//    capacity = {
//      storage = "450Gi"
//    }
//    storage_class_name = "standard"
//    access_modes = ["ReadWriteOnce"]
//    persistent_volume_source {
//      gce_persistent_disk {
//        pd_name = var.gcp-disk-id
//        fs_type = "ext4"
//      }
//    }
//  }
//}
//
//resource "kubernetes_persistent_volume_claim" "testing-data" {
//    metadata {
//    name      = "testing-data-pvc"
//    namespace = var.namespace
//  }
//  spec {
//    storage_class_name = "standard"
//    access_modes       = ["ReadWriteOnce"]
//    volume_name        = kubernetes_persistent_volume.testing-data-volume.metadata.0.name
//    resources {
//      requests = {
//        storage = "450Gi"
//      }
//    }
//  }
//}
//
//
//resource "kubernetes_deployment" "benchmark-tool" {
//  metadata {
//    name      = "benchmark-tool"
//    namespace = var.namespace
//    labels = {
//      app = "benchmark-tool"
//    }
//  }
//
//  spec {
//    replicas = 1
//    selector {
//      match_labels = {
//        app = "benchmark-tool"
//      }
//    }
//
//
//    template {
//      metadata {
//        labels = {
//          app = "benchmark-tool"
//        }
//      }
//
//      spec {
//        container {
//          image = "fluentbitdev/fluent-bit-ci:benchmark"
//          name  = "benchmark-tool"
//          command = [ "/bin/sh"]
//          args = [ "-c", "python /run_log_generator.py --log-size-in-bytes 1000 --log-rate 200000 --log-agent-input-type tail --tail-file-path /data/test.log"]
//          resources {
//            limits = {
//              cpu    = "2000m"
//              memory = "2048Mi"
//            }
//            requests = {
//              cpu    = "2000m"
//              memory = "1024Mi"
//            }
//          }
//
//          volume_mount {
//            mount_path = "/data"
//            name       = "nfs-data"
//          }
//        }
//        volume {
//          name = "nfs-data"
//          persistent_volume_claim {
//            claim_name = kubernetes_persistent_volume_claim.testing-data.metadata.0.name
//          }
//        }
//      }
//    }
//  }
//}
