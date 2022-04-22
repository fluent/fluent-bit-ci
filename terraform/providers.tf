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
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_id
  secret_key = var.aws_secret_key
}