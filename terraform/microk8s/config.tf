//terraform {
//  required_providers {
//    lxd = {
//      source = "terraform-lxd/lxd"
//      version = "1.5.0"
//    }
//  }
//  backend "remote" {
//    organization = "calyptia"
//    hostname     = "app.terraform.io"
//
//    workspaces {
//      name = "fluent-bit-ci"
//    }
//  }
//}