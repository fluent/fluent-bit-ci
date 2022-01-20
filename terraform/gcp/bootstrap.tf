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

resource "google_compute_network" "vpc" {
  name                    = "vpc-${var.k8s-version-formatted}"
  auto_create_subnetworks = true
}

resource "google_container_cluster" "fluent-bit-ci-autopilot-cluster" {
  count = var.gke-enable-autopilot ? 1 : 0

  enable_autopilot   = true

  name               = "${var.k8s-cluster-name}-gke-${var.k8s-version-formatted}-autopilot"
  location           = var.gcp-default-zone
  network            = google_compute_network.vpc.name

  depends_on         = [ data.google_project.project ]
}

resource "google_container_cluster" "fluent-bit-ci-k8s-cluster" {
  count = var.gke-enable-autopilot ? 0 : 1

  name               = "${var.k8s-cluster-name}-gke-${var.k8s-version-formatted}"
  location           = var.gcp-default-zone
  network            = google_compute_network.vpc.name

  node_locations     = var.k8s-additional-zones
  node_version       = data.google_container_engine_versions.versions.latest_node_version
  min_master_version = data.google_container_engine_versions.versions.latest_master_version

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

  depends_on = [data.google_project.project, data.google_container_engine_versions.versions]
}

resource "random_id" "random_prefix" {
  byte_length = 6
}

resource "google_bigquery_dataset" "testing-dataset" {
  dataset_id    = "testing_dataset"
  friendly_name = "test_dataset"
}

resource "google_bigquery_table" "testing-table" {
  dataset_id = google_bigquery_dataset.testing-dataset.dataset_id
  table_id   = "testing-table-${random_id.random_prefix.hex}"
  schema     = <<EOF
[
  {
    "name": "message",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "message"
  }
]
EOF
}

output "k8s-cluster-name" {
  value = "${element(compact(concat(google_container_cluster.fluent-bit-ci-k8s-cluster.*.name, google_container_cluster.fluent-bit-ci-autopilot-cluster.*.name)),0)}"
}

output "gcp-bigquery-dataset-id" {
  value = google_bigquery_dataset.testing-dataset.dataset_id
}

output "gcp-bigquery-table-id" {
  value = google_bigquery_table.testing-table.table_id
}
output "gcp-project-id" {
  value = var.gcp-project-id
}

output "k8s-cluster-location" {
  value = "${element(compact(concat(google_container_cluster.fluent-bit-ci-k8s-cluster.*.location, google_container_cluster.fluent-bit-ci-autopilot-cluster.*.location)),0)}"
}
