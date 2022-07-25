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

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
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

  # Always use latest
  node_version = data.google_container_engine_versions.versions.latest_node_version

  # Enabling Autopilot for this cluster
  enable_autopilot = true

  # Required to handle this issue: https://github.com/hashicorp/terraform-provider-google/issues/10782
  ip_allocation_policy {}

  depends_on = [data.google_project.project]
}
