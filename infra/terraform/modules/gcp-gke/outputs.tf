output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.this.name
}

output "cluster_endpoint" {
  description = "Cluster API endpoint."
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate."
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "Region of the cluster."
  value       = google_container_cluster.this.location
}

output "workload_identity_pool" {
  description = "Workload Identity pool of the form '<project>.svc.id.goog'."
  value       = "${var.gcp_project_id}.svc.id.goog"
}

output "node_pool_name" {
  description = "Primary node pool name."
  value       = google_container_node_pool.primary.name
}
