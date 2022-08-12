# Provide Azure and GKE clusters to run tests on.

## Azure
resource "azurerm_resource_group" "fluent-bit-ci" {
  name     = "fluent-bit-ci-k8s-resources"
  location = var.azure_location
}

resource "azurerm_kubernetes_cluster" "fluent-bit-ci" {
  name                = "fluent-bit-ci-k8s"
  location            = azurerm_resource_group.fluent-bit-ci.location
  resource_group_name = azurerm_resource_group.fluent-bit-ci.name
  dns_prefix          = "fluent-bit-ci-k8s"
  # AKS defaults to latest K8S version

  default_node_pool {
    name            = "default"
    node_count      = 5
    vm_size         = "Standard_DS2_v2"
    os_disk_size_gb = 150
  }

  service_principal {
    client_id     = var.azure_client_id
    client_secret = var.azure_client_secret
  }
}

output "aks_cluster_name" {
  value       = azurerm_kubernetes_cluster.fluent-bit-ci.name
  description = "AKS cluster name"
}

output "aks_resource_group" {
  value       = azurerm_resource_group.fluent-bit-ci.name
  description = "AKS cluster resource group"
}

## GKE
data "google_project" "project" {}
data "google_client_config" "current" {}

# Provide information about versions available to this region
data "google_container_engine_versions" "versions" {
  location = var.gcp_region
}

resource "google_compute_network" "vpc" {
  name                    = "vpc-fluent-bit-ci"
  auto_create_subnetworks = true
}

resource "google_container_cluster" "fluent-bit-ci-autopilot" {
  name = "fluent-bit-ci-autopilot"
  # For autopilot we must use regional clusters
  location = var.gcp_region

  initial_node_count = 1
  network            = google_compute_network.vpc.name

  # Enabling Autopilot for this cluster
  enable_autopilot = true

  # Required to handle this issue: https://github.com/hashicorp/terraform-provider-google/issues/10782
  ip_allocation_policy {}

  depends_on = [data.google_project.project]
}

resource "google_container_cluster" "fluent-bit-ci" {
  name = "fluent-bit-ci"
  # For autopilot we must use regional clusters
  location = var.gcp_region

  network            = google_compute_network.vpc.name
  initial_node_count = 1
  remove_default_node_pool = "true"

  depends_on = [data.google_project.project]
}

resource "google_container_node_pool" "fluent-bit-ci" {
  name       = "fluent-bit-ci-node-pool"
  cluster    = google_container_cluster.fluent-bit-ci.name
  location   = google_container_cluster.fluent-bit-ci.location
  node_count = 6

  autoscaling {
    # Minimum number of nodes in the NodePool. Must be >=0 and <= max_node_count.
    min_node_count = 3

    # Maximum number of nodes in the NodePool. Must be >= min_node_count.
    max_node_count = 24
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    # Taken from Elastic example:
    # https://cloud.google.com/architecture/deploying-migrating-elastic-cloud-kubernetes-to-google-cloud#create_the_gke_cluster
    machine_type = "n1-standard-4"
    disk_size_gb = "256"
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/sqlservice.admin",
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_write",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

}

output "gke_region" {
  value       = var.gcp_region
  description = "GCloud Region"
}

output "gke_kubernetes_cluster_name" {
  value       = google_container_cluster.fluent-bit-ci.name
  description = "GKE Cluster Name"
}
