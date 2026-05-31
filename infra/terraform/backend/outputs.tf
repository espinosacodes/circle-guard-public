output "state_bucket_name" {
  description = "Name of the GCS bucket holding Terraform state. Paste this into each env's backend.tf."
  value       = google_storage_bucket.tfstate.name
}

output "state_bucket_url" {
  description = "gs:// URL of the state bucket."
  value       = google_storage_bucket.tfstate.url
}

output "state_bucket_location" {
  description = "Region of the state bucket."
  value       = google_storage_bucket.tfstate.location
}
