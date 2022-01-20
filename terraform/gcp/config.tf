terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      # Step up once merged: https://github.com/GoogleCloudPlatform/magic-modules/pull/5540
      # See: https://github.com/hashicorp/terraform-provider-google/issues/10782
      version = "4.3.0"
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
