provider "helm" {
  kubernetes {
    config_path = "client.config"
  }
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
}