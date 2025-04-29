terraform {
  required_providers {
    alicloud = {
      source  = "hashicorp/alicloud"
      version = "1.248.0"
    }
  }

  required_version = ">= 1.8.0"
}

resource "random_string" "suffix" {
  length  = 16
  lower   = true
  upper   = false
  special = false
}
