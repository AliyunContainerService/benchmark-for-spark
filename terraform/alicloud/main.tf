terraform {
  required_providers {
    alicloud = {
      source  = "hashicorp/alicloud"
      version = "1.213.0"
    }
  }

  required_version = ">= 1.6.0"
}

resource "random_string" "suffix" {
  length  = 16
  lower   = true
  upper   = false
  special = false
}
