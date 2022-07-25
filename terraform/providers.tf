terraform {
  cloud {
    organization = "calyptia"

    workspaces {
      name = "calyptia-opensearch"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.1"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 4.29"
    }
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_id
  secret_key = var.aws_secret_key
}

provider "azurerm" {
  features {}
}

provider "google" {
  project     = var.gcp_project + id
  region      = var.gcp_region
  credentials = var.gcp_sa_key
}
