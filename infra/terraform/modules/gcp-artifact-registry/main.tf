terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

locals {
  name_prefix = "${var.project_prefix}-${var.env}"

  default_labels = {
    env        = var.env
    project    = var.project_prefix
    managed-by = "terraform"
  }
}

resource "google_artifact_registry_repository" "docker" {
  location      = var.region
  repository_id = "${local.name_prefix}-docker"
  description   = "Docker images for ${var.project_prefix} (${var.env})"
  format        = "DOCKER"

  cleanup_policies {
    id     = "keep-recent-30"
    action = "KEEP"
    most_recent_versions {
      keep_count = 30
    }
  }

  cleanup_policies {
    id     = "delete-untagged-after-14d"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "1209600s" # 14 days
    }
  }

  labels = local.default_labels
}
