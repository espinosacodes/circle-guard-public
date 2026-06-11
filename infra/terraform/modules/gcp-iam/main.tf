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
}

# --- CI/CD service account (used by Jenkins / GitHub Actions) ---
resource "google_service_account" "cicd" {
  account_id   = "${local.name_prefix}-cicd"
  display_name = "CircleGuard CI/CD (${var.env})"
  description  = "Used by pipelines to build images, push to AR, and deploy to GKE."
}

resource "google_project_iam_member" "cicd_ar_writer" {
  project = var.gcp_project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_project_iam_member" "cicd_gke_developer" {
  project = var.gcp_project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_project_iam_member" "cicd_sa_user" {
  project = var.gcp_project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# --- GKE node service account (least-privilege replacement for default compute SA) ---
resource "google_service_account" "gke_nodes" {
  account_id   = "${local.name_prefix}-gke-nodes"
  display_name = "CircleGuard GKE nodes (${var.env})"
}

resource "google_project_iam_member" "gke_nodes_log_writer" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_metric_writer" {
  project = var.gcp_project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring_viewer" {
  project = var.gcp_project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_ar_reader" {
  project = var.gcp_project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# --- Workload Identity binding: one GSA per (k8s namespace, k8s SA) pair ---
resource "google_service_account" "workload" {
  for_each = { for w in var.workload_identity_bindings : "${w.k8s_namespace}_${w.k8s_sa}" => w }

  account_id   = substr("${local.name_prefix}-${each.value.k8s_namespace}-${each.value.k8s_sa}", 0, 30)
  display_name = "WI ${each.value.k8s_namespace}/${each.value.k8s_sa}"
}

resource "google_service_account_iam_member" "workload_binding" {
  for_each = var.create_workload_identity_pool_bindings ? {
    for w in var.workload_identity_bindings : "${w.k8s_namespace}_${w.k8s_sa}" => w
  } : {}

  service_account_id = google_service_account.workload[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project_id}.svc.id.goog[${each.value.k8s_namespace}/${each.value.k8s_sa}]"
}

# Extra project-level roles per workload (e.g. Cloud SQL client for the app SA)
resource "google_project_iam_member" "workload_role" {
  for_each = {
    for pair in flatten([
      for w in var.workload_identity_bindings : [
        for r in w.roles : {
          key  = "${w.k8s_namespace}_${w.k8s_sa}_${r}"
          gsa  = "${w.k8s_namespace}_${w.k8s_sa}"
          role = r
        }
      ]
    ]) : pair.key => pair
  }

  project = var.gcp_project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.workload[each.value.gsa].email}"
}
