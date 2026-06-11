variable "gcp_project_id" {
  description = "GCP project ID for stage."
  type        = string
}

variable "gcp_region" {
  description = "Primary GCP region."
  type        = string
  default     = "us-central1"
}

variable "project_prefix" {
  description = "Resource naming prefix."
  type        = string
  default     = "circleguard"
}

variable "env" {
  description = "Environment name."
  type        = string
  default     = "stage"
}

# --- GCP network ---
variable "subnet_cidr" {
  type    = string
  default = "10.40.0.0/20"
}

variable "pods_cidr" {
  type    = string
  default = "10.50.0.0/16"
}

variable "services_cidr" {
  type    = string
  default = "10.60.0.0/20"
}

# --- GKE ---
variable "gke_machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "gke_node_count_min" {
  type    = number
  default = 1
}

variable "gke_node_count_max" {
  type    = number
  default = 4
}

variable "gke_preemptible" {
  type    = bool
  default = true
}

# --- CloudSQL ---
variable "cloudsql_tier" {
  type    = string
  default = "db-custom-1-3840"
}

# --- Azure ---
variable "azure_subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "azure_location" {
  description = "Azure region."
  type        = string
  default     = "eastus"
}

variable "azure_vnet_cidr" {
  type    = string
  default = "10.70.0.0/16"
}

variable "azure_aks_subnet_cidr" {
  type    = string
  default = "10.70.0.0/20"
}

variable "azure_appgw_subnet_cidr" {
  type    = string
  default = "10.70.16.0/24"
}

variable "aks_system_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "aks_user_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "aks_user_node_min" {
  type    = number
  default = 1
}

variable "aks_user_node_max" {
  type    = number
  default = 3
}

variable "aks_spot_enabled" {
  type    = bool
  default = true
}

# --- OCI ---
# Authenticated via TF_VAR_* env vars sourced from ~/.oci/oci.env on the
# student's workstation. No defaults here so accidental commits never leak.
variable "tenancy_ocid" {
  description = "OCI tenancy OCID. Pre-set via TF_VAR_tenancy_ocid."
  type        = string
}

variable "user_ocid" {
  description = "OCI user OCID. Pre-set via TF_VAR_user_ocid."
  type        = string
}

variable "compartment_id" {
  description = "OCI compartment OCID. Defaults to root compartment (tenancy OCID) in the trial."
  type        = string
}

variable "oci_region" {
  description = "OCI region identifier, e.g. sa-bogota-1."
  type        = string
  default     = "sa-bogota-1"
}

variable "oci_fingerprint" {
  description = "OCI API key fingerprint. Pre-set via TF_VAR_oci_fingerprint."
  type        = string
}

variable "oci_private_key_path" {
  description = "Path to OCI API private key PEM. Pre-set via TF_VAR_oci_private_key_path."
  type        = string
}

variable "oci_tenancy_namespace" {
  description = "OCI Object Storage namespace for the tenancy (used to build OCIR FQDNs)."
  type        = string
}

variable "oci_vcn_cidr" {
  type    = string
  default = "10.120.0.0/16"
}

variable "oci_public_subnet_cidr" {
  type    = string
  default = "10.120.0.0/24"
}

variable "oci_private_subnet_cidr" {
  type    = string
  default = "10.120.1.0/24"
}

variable "oke_kubernetes_version" {
  type    = string
  default = "v1.30.1"
}

variable "oke_node_image_id" {
  description = "OCID of the OKE-compatible OS image. Look up with `oci ce node-pool-options get --node-pool-option-id all`."
  type        = string
}

variable "oke_node_count" {
  type    = number
  default = 1
}

variable "oci_edge_vm_image_id" {
  description = "OCID of an x86_64 Oracle Linux 8 image (NOT GPU, NOT OKE). Fetched via `oci compute image list --operating-system 'Oracle Linux' --operating-system-version 8`."
  type        = string
}
