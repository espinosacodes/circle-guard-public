output "vpc_id" {
  description = "Self-link of the VPC."
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "Name of the VPC."
  value       = google_compute_network.vpc.name
}

output "vpc_self_link" {
  description = "Self-link of the VPC."
  value       = google_compute_network.vpc.self_link
}

output "subnet_id" {
  description = "Self-link of the GKE node subnet."
  value       = google_compute_subnetwork.gke.id
}

output "subnet_name" {
  description = "Name of the GKE node subnet."
  value       = google_compute_subnetwork.gke.name
}

output "pods_range_name" {
  description = "Secondary range name for pods."
  value       = "${var.project_prefix}-${var.env}-pods"
}

output "services_range_name" {
  description = "Secondary range name for services."
  value       = "${var.project_prefix}-${var.env}-services"
}

output "private_service_connection_id" {
  description = "ID of the Service Networking peering, needed by CloudSQL with private IP."
  value       = google_service_networking_connection.private_vpc_connection.id
}
