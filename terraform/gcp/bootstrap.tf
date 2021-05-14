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

resource "random_id" "disk" {
  byte_length = 8
}

resource "google_compute_disk" "testing-data" {
  name = "testing-data-${random_id.disk.hex}"
  type = "pd-ssd"
  zone = var.gcp-default-zone
  size = 450
}

output "k8s-cluster-name" {
  value = google_container_cluster.fluent-bit-ci-k8s-cluster.name
}

output "gcp-disk-id" {
  value = google_compute_disk.testing-data.name
}

output "gcp-project-id" {
  value = var.gcp-project-id
}

output "k8s-cluster-location" {
  value = google_container_cluster.fluent-bit-ci-k8s-cluster.location
}
