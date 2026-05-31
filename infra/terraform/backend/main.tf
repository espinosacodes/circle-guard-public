terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

locals {
  bucket_name = coalesce(
    var.state_bucket_name,
    "${var.project_prefix}-tfstate-${var.gcp_project_id}"
  )

  default_labels = {
    project     = var.project_prefix
    managed-by  = "terraform"
    env         = "shared"
    component   = "tfstate"
  }
}

resource "google_storage_bucket" "tfstate" {
  name          = local.bucket_name
  location      = var.gcp_region
  storage_class = "STANDARD"

  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  labels = local.default_labels
}
