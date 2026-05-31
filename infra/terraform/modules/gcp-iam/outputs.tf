output "cicd_service_account_email" {
  description = "Email of the CI/CD service account."
  value       = google_service_account.cicd.email
}

output "gke_node_service_account_email" {
  description = "Email of the dedicated GKE node service account. Wire this into the gcp-gke module."
  value       = google_service_account.gke_nodes.email
}

output "workload_identity_service_accounts" {
  description = "Map of '<ns>_<sa>' => GSA email for each WI binding."
  value       = { for k, sa in google_service_account.workload : k => sa.email }
}
