terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.10.0"
    }
  }
  backend "remote" {
    organization = "calyptia"
    hostname     = "app.terraform.io"

    workspaces {
      name = "fluent-bit-ci-gke-1-19"
    }
  }
}
