terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }
}
