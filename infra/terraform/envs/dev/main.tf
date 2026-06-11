provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# --- Networking ---
module "network" {
  source = "../../modules/gcp-network"

  project_prefix = var.project_prefix
  env            = var.env
  region         = var.gcp_region

  subnet_cidr   = var.subnet_cidr
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr
}

# --- IAM (service accounts) ---
module "iam" {
  source = "../../modules/gcp-iam"

  project_prefix                         = var.project_prefix
  env                                    = var.env
  gcp_project_id                         = var.gcp_project_id
  create_workload_identity_pool_bindings = false

  workload_identity_bindings = [
    {
      k8s_namespace = "circleguard"
      k8s_sa        = "app"
      roles = [
        "roles/cloudsql.client",
        "roles/secretmanager.secretAccessor",
      ]
    },
  ]
}

# --- GKE ---
module "gke" {
  source = "../../modules/gcp-gke"

  project_prefix = var.project_prefix
  env            = var.env
  gcp_project_id = var.gcp_project_id
  region         = var.gcp_region

  network             = module.network.vpc_self_link
  subnetwork          = module.network.subnet_id
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name

  machine_type         = var.gke_machine_type
  node_count_min       = var.gke_node_count_min
  node_count_max       = var.gke_node_count_max
  preemptible          = var.gke_preemptible
  node_service_account = module.iam.gke_node_service_account_email
  deletion_protection  = false
}

resource "google_service_account_iam_member" "app_workload_identity" {
  service_account_id = "projects/${var.gcp_project_id}/serviceAccounts/${module.iam.workload_identity_service_accounts["circleguard_app"]}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${module.gke.workload_identity_pool}[circleguard/app]"
}

# --- Cloud SQL ---
module "cloudsql" {
  source = "../../modules/gcp-cloudsql"

  project_prefix                = var.project_prefix
  env                           = var.env
  region                        = var.gcp_region
  network                       = module.network.vpc_self_link
  private_service_connection_id = module.network.private_service_connection_id

  tier                = var.cloudsql_tier
  availability_type   = "ZONAL"
  deletion_protection = false
}

# --- Artifact Registry ---
module "artifact_registry" {
  source = "../../modules/gcp-artifact-registry"

  project_prefix = var.project_prefix
  env            = var.env
  region         = var.gcp_region
}

# --- Outputs ---
output "gke_cluster_name" {
  value = module.gke.cluster_name
}

output "gke_get_credentials_cmd" {
  value = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.gcp_region} --project ${var.gcp_project_id}"
}

output "artifact_registry_url" {
  value = module.artifact_registry.repository_url
}

output "cloudsql_connection_name" {
  value = module.cloudsql.instance_connection_name
}

output "cicd_service_account_email" {
  value = module.iam.cicd_service_account_email
}
