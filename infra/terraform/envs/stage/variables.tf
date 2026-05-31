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
