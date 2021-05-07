provider "google" {
  project     = var.gcp-project-id
  region      = var.gcp-default-region
  credentials = var.gcp-sa-key
}

data "google_project" "project" {}
data "google_client_config" "current" {}

data "google_container_engine_versions" "versions" {
  location       = var.gcp-default-zone
  version_prefix = "${var.k8s-version}."
}

# Shared network for GKE cluster and Filestore to use.
resource "google_compute_network" "vpc" {
  name                    = "shared-vpc-${var.k8s-version-formatted}"
  auto_create_subnetworks = true
}

resource "google_container_cluster" "fluent-bit-ci-k8s-cluster" {
  name           = "${var.k8s-cluster-name}-gke-${var.k8s-version-formatted}"
  location       = var.gcp-default-zone
  node_locations = var.k8s-additional-zones
  monitoring_service = "monitoring.googleapis.com/kubernetes"
  network            = google_compute_network.vpc.name
  release_channel {
    channel = "RAPID"
  }

  node_version       = var.k8s-version
  min_master_version = var.k8s-version

  initial_node_count = 1

  node_config {
    machine_type = var.k8s-machine-type
    disk_size_gb = var.k8s-disk-size
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_write",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

  depends_on         = [data.google_project.project, data.google_container_engine_versions.versions]
}

resource "google_filestore_instance" "test-nfs-server" {
  name = "test-nfs-server-${var.k8s-version-formatted}"
  tier = "STANDARD"
  zone = var.gcp-default-zone

  file_shares {
    capacity_gb = 1024
    name        = "vol1"
  }

  networks {
    network = google_compute_network.vpc.name
    modes   = ["MODE_IPV4"]
  }
}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.fluent-bit-ci-k8s-cluster.endpoint}"
  token                  = data.google_client_config.current.access_token
  client_certificate     = base64decode(google_container_cluster.fluent-bit-ci-k8s-cluster.master_auth.0.client_certificate)
  client_key             = base64decode(google_container_cluster.fluent-bit-ci-k8s-cluster.master_auth.0.client_key)
  cluster_ca_certificate = base64decode(google_container_cluster.fluent-bit-ci-k8s-cluster.master_auth.0.cluster_ca_certificate)
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
        server = google_filestore_instance.test-nfs-server.networks[0].ip_addresses[0]
        path   = "/${google_filestore_instance.test-nfs-server.file_shares[0].name}"
      }
    }
  }
}

output "nfs-storage-class" {
  value = kubernetes_storage_class.nfs.metadata[0].name
}

output "nfs-storage-volume" {
  value = kubernetes_persistent_volume.nfs-volume.metadata[0].name
}

output "k8s-cluster-name" {
  value = google_container_cluster.fluent-bit-ci-k8s-cluster.name
}

output "gcp-project-id" {
  value = var.gcp-project-id
}

output "k8s-cluster-location" {
  value = google_container_cluster.fluent-bit-ci-k8s-cluster.location
}
