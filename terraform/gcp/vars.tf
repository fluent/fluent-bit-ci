variable "gcp-project-id" {
  type    = string
  default = "fluent-bit-ci"
}

variable "gcp-default-region" {
  type    = string
  default = "us-east1"
}

variable "gcp-default-zone" {
  type    = string
  default = "us-east1-c"
}

variable "gcp-sa-key" {
  type = string
}

variable "k8s-min-node-count" {
  default = "1"
}

variable "k8s-max-node-count" {
  default = "3"
}

variable "k8s-version" {
  type = string
}

variable "k8s-version-formatted" {
  type = string
}

variable "k8s-cluster-name" {
  type    = string
  default = "fluent-bit-ci"
}

variable "k8s-machine-type" {
  type    = string
  default = "e2-highcpu-16"
}

variable "k8s-additional-zones" {
  type    = list(string)
  default = []
}

variable "k8s-disk-size" {
  type    = string
  default = 500
}
