output "registry_host" {
  description = "OCIR host for the region, e.g. sa-bogota-1.ocir.io."
  value       = "${var.region_key}.ocir.io"
}

output "repository_ids" {
  description = "Map of service name -> repository OCID."
  value       = { for k, r in oci_artifacts_container_repository.svc : k => r.id }
}

output "repository_fqdns" {
  description = "Map of service name -> fully qualified OCIR path, e.g. sa-bogota-1.ocir.io/<ns>/circleguard/stage/gateway-service."
  value = {
    for k, _ in oci_artifacts_container_repository.svc :
    k => "${var.region_key}.ocir.io/${var.tenancy_namespace}/${lower(var.project_prefix)}/${var.env}/${k}"
  }
}

output "repository_root_url" {
  description = "Root path for all CircleGuard repos in this tenancy, e.g. sa-bogota-1.ocir.io/<ns>/circleguard."
  value       = "${var.region_key}.ocir.io/${var.tenancy_namespace}/${lower(var.project_prefix)}"
}
