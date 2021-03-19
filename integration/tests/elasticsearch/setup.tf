provider "helm" {
  kubernetes {
    config_path = "client.config"
  }
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

resource "helm_release" "fluent-bit" {
  name       = "fluent-bit"
  namespace  = var.namespace
  force_update = true
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  values = [data.local_file.fluent-bit-config.content]
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = var.namespace
  values = [data.local_file.prometheus-config.content]
}

resource "helm_release" "elasticsearch" {
  name       = "elasticsearch"
  namespace  = var.namespace
  repository = "https://helm.elastic.co"
  chart      = "elasticsearch"
  force_update = true

  set {
    name = "replicas"
    value = "1"
  }

  set {
    name = "minMasterNodes"
    value = "1"
  }
}
