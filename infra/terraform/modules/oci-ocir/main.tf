terraform {
  required_version = ">= 1.5"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0"
    }
  }
}

locals {
  # OCIR repository names: lowercase, slash-separated. Mirrors the ACR
  # globally-unique-name pattern but scoped to the tenancy namespace.
  repo_prefix = lower("${var.project_prefix}/${var.env}")

  default_freeform_tags = {
    env        = var.env
    project    = var.project_prefix
    managed-by = "terraform"
  }
}

# Each microservice gets its own OCIR repo so we can RBAC them individually.
resource "oci_artifacts_container_repository" "svc" {
  for_each = toset(var.service_names)

  compartment_id = var.compartment_id
  display_name   = "${local.repo_prefix}/${each.value}"
  is_immutable   = false
  is_public      = var.is_public

  readme {
    content = "CircleGuard ${var.env} container image for ${each.value}. Managed by Terraform."
    format  = "text/plain"
  }

  freeform_tags = local.default_freeform_tags
}
