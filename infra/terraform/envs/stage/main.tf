## =====================================================================
##  CircleGuard stage — currently OCI-only.
##
##  GCP modules are commented out because the original project
##  `circleguard-final-92308` was deleted on 2026-06-03. Re-enable
##  the GCP block once the teammate's replacement project ID is
##  wired into terraform.tfvars.
##
##  Azure modules are commented out because the Student subscription
##  is blocked. Re-enable if/when `azure_subscription_id` becomes
##  a real value.
##
##  OCI remains active — Always Free Ampere ARM (sa-bogota-1).
## =====================================================================

# provider "google" {
#   project = var.gcp_project_id
#   region  = var.gcp_region
# }

# provider "azurerm" {
#   subscription_id = var.azure_subscription_id
#   features {}
# }

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.oci_fingerprint
  private_key_path = var.oci_private_key_path
  region           = var.oci_region
}

# =====================================================
# GCP (primary) — DISABLED while teammate reprovisions
# =====================================================
# module "network" {
#   source = "../../modules/gcp-network"
#
#   project_prefix = var.project_prefix
#   env            = var.env
#   region         = var.gcp_region
#
#   subnet_cidr   = var.subnet_cidr
#   pods_cidr     = var.pods_cidr
#   services_cidr = var.services_cidr
# }
#
# module "iam" {
#   source = "../../modules/gcp-iam"
#
#   project_prefix = var.project_prefix
#   env            = var.env
#   gcp_project_id = var.gcp_project_id
#
#   workload_identity_bindings = [
#     {
#       k8s_namespace = "circleguard"
#       k8s_sa        = "app"
#       roles = [
#         "roles/cloudsql.client",
#         "roles/secretmanager.secretAccessor",
#       ]
#     },
#   ]
# }
#
# module "gke" {
#   source = "../../modules/gcp-gke"
#
#   project_prefix = var.project_prefix
#   env            = var.env
#   gcp_project_id = var.gcp_project_id
#   region         = var.gcp_region
#
#   network             = module.network.vpc_self_link
#   subnetwork          = module.network.subnet_id
#   pods_range_name     = module.network.pods_range_name
#   services_range_name = module.network.services_range_name
#
#   machine_type         = var.gke_machine_type
#   node_count_min       = var.gke_node_count_min
#   node_count_max       = var.gke_node_count_max
#   preemptible          = var.gke_preemptible
#   node_service_account = module.iam.gke_node_service_account_email
#   deletion_protection  = false
# }
#
# module "cloudsql" {
#   source = "../../modules/gcp-cloudsql"
#
#   project_prefix                = var.project_prefix
#   env                           = var.env
#   region                        = var.gcp_region
#   network                       = module.network.vpc_self_link
#   private_service_connection_id = module.network.private_service_connection_id
#
#   tier                = var.cloudsql_tier
#   availability_type   = "ZONAL"
#   deletion_protection = true
# }
#
# module "artifact_registry" {
#   source = "../../modules/gcp-artifact-registry"
#
#   project_prefix = var.project_prefix
#   env            = var.env
#   region         = var.gcp_region
# }

# =====================================================
# Azure (secondary — multi-cloud) — DISABLED (sub blocked)
# =====================================================
# module "azure_network" {
#   source = "../../modules/azure-network"
#
#   project_prefix    = var.project_prefix
#   env               = var.env
#   location          = var.azure_location
#   vnet_cidr         = var.azure_vnet_cidr
#   aks_subnet_cidr   = var.azure_aks_subnet_cidr
#   appgw_subnet_cidr = var.azure_appgw_subnet_cidr
# }
#
# module "azure_aks" {
#   source = "../../modules/azure-aks"
#
#   project_prefix      = var.project_prefix
#   env                 = var.env
#   location            = module.azure_network.resource_group_location
#   resource_group_name = module.azure_network.resource_group_name
#   subnet_id           = module.azure_network.aks_subnet_id
#
#   system_vm_size = var.aks_system_vm_size
#   user_vm_size   = var.aks_user_vm_size
#   user_node_min  = var.aks_user_node_min
#   user_node_max  = var.aks_user_node_max
#
#   spot_enabled = var.aks_spot_enabled
# }
#
# module "azure_acr" {
#   source = "../../modules/azure-acr"
#
#   project_prefix                 = var.project_prefix
#   env                            = var.env
#   location                       = module.azure_network.resource_group_location
#   resource_group_name            = module.azure_network.resource_group_name
#   sku                            = "Standard"
#   name_suffix                    = substr(sha1(var.azure_subscription_id), 0, 6)
#   aks_kubelet_identity_object_id = module.azure_aks.kubelet_identity_object_id
# }

# =====================================================
# OCI (secondary — multi-cloud, replaces Azure on this pivot)
# Always-Free Ampere ARM worker pool, single AD (SWmf:SA-BOGOTA-1-AD-1).
# =====================================================
module "oci_network" {
  source = "../../modules/oci-network"

  project_prefix      = var.project_prefix
  env                 = var.env
  compartment_id      = var.compartment_id
  vcn_cidr            = var.oci_vcn_cidr
  public_subnet_cidr  = var.oci_public_subnet_cidr
  private_subnet_cidr = var.oci_private_subnet_cidr
}

module "oci_oke" {
  source = "../../modules/oci-oke"

  project_prefix        = var.project_prefix
  env                   = var.env
  compartment_id        = var.compartment_id
  vcn_id                = module.oci_network.vcn_id
  public_subnet_id      = module.oci_network.public_subnet_id
  private_subnet_id     = module.oci_network.private_subnet_id
  kubernetes_version    = var.oke_kubernetes_version
  node_image_id         = var.oke_node_image_id
  node_count            = var.oke_node_count
  region_for_kubeconfig = var.oci_region
}

module "oci_ocir" {
  source = "../../modules/oci-ocir"

  project_prefix    = var.project_prefix
  env               = var.env
  compartment_id    = var.compartment_id
  tenancy_namespace = var.oci_tenancy_namespace
  region_key        = var.oci_region
}

# Always-Free AMD edge VM — DEFERRED.
# sa-bogota-1 returned 404-NotAuthorizedOrNotFound (Oracle's shorthand for
# "out of capacity for this shape, today") on both A1.Flex (OKE node pool)
# and E2.1.Micro (this VM). Same error class on E2.1 and E4.Flex too.
# The module is fully written under `infra/terraform/modules/oci-vm/` and
# tested against the same image OCID — just un-comment to re-attempt once
# Oracle Bogotá capacity returns.
#
# module "oci_edge_vm" {
#   source = "../../modules/oci-vm"
#
#   project_prefix = var.project_prefix
#   env            = var.env
#   compartment_id = var.compartment_id
#   subnet_id      = module.oci_network.public_subnet_id
#   image_id       = var.oci_edge_vm_image_id
# }

# --- Outputs (OCI only) ---
output "oke_cluster_name" {
  value = module.oci_oke.cluster_name
}

output "oke_get_kubeconfig_cmd" {
  value = module.oci_oke.get_kubeconfig_cmd
}

output "ocir_repo_url" {
  value = module.oci_ocir.repository_root_url
}

# output "oci_edge_demo_url" {
#   description = "Live URL on OCI — opens the multi-cloud demo page."
#   value       = module.oci_edge_vm.demo_url
# }
