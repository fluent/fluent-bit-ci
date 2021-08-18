provider "helm" {
  kubernetes {
    config_path = "client.config"
  }
}
provider "kubernetes" {
  config_path = "client.config"
}

variable "gcp-sa-key" {
  type = string
}

variable "prometheus-config" {
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
  name         = "fluent-bit"
  namespace    = var.namespace
  force_update = true
  repository   = "https://fluent.github.io/helm-charts"
  chart        = "fluent-bit"
  values       = [data.local_file.fluent-bit-config.content]
  depends_on   = [kubernetes_secret.service_account_data]
  wait         = true
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = var.namespace
  values     = [data.local_file.prometheus-config.content]
}
