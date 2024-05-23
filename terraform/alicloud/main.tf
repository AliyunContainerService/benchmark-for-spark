terraform {
  required_providers {
    alicloud = {
      source  = "hashicorp/alicloud"
      version = "1.223.2"
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
