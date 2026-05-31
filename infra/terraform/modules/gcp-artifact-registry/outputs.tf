output "repository_id" {
  description = "Repository id (short)."
  value       = google_artifact_registry_repository.docker.repository_id
}

output "repository_name" {
  description = "Fully qualified repository resource name."
  value       = google_artifact_registry_repository.docker.name
}

output "repository_url" {
  description = "Docker pull/push URL, e.g. us-central1-docker.pkg.dev/<project>/<repo>"
  value       = "${google_artifact_registry_repository.docker.location}-docker.pkg.dev/${google_artifact_registry_repository.docker.project}/${google_artifact_registry_repository.docker.repository_id}"
}
