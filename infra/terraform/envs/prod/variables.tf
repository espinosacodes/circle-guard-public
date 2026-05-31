variable "gcp_project_id" {
  description = "GCP project ID for prod."
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
  default     = "prod"
}

# --- GCP network (prod CIDRs, no overlap with dev/stage) ---
variable "subnet_cidr" {
  type    = string
  default = "10.80.0.0/20"
}

variable "pods_cidr" {
  type    = string
  default = "10.90.0.0/16"
}

variable "services_cidr" {
  type    = string
  default = "10.100.0.0/20"
}

# --- GKE — HA defaults ---
variable "gke_machine_type" {
  type    = string
  default = "e2-standard-4"
}

variable "gke_node_count_min" {
  type    = number
  default = 2
}

variable "gke_node_count_max" {
  type    = number
  default = 6
}

variable "gke_preemptible" {
  description = "Default OFF in prod for SLA; set true on a separate spot pool if cost matters."
  type        = bool
  default     = false
}

# --- CloudSQL — REGIONAL HA, larger tier ---
variable "cloudsql_tier" {
  type    = string
  default = "db-custom-2-7680"
}

variable "cloudsql_availability_type" {
  type    = string
  default = "REGIONAL"
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
  default = "10.110.0.0/16"
}

variable "azure_aks_subnet_cidr" {
  type    = string
  default = "10.110.0.0/20"
}

variable "azure_appgw_subnet_cidr" {
  type    = string
  default = "10.110.16.0/24"
}

variable "aks_system_vm_size" {
  type    = string
  default = "Standard_D2s_v5"
}

variable "aks_user_vm_size" {
  type    = string
  default = "Standard_D2s_v5"
}

variable "aks_user_node_min" {
  type    = number
  default = 2
}

variable "aks_user_node_max" {
  type    = number
  default = 6
}

variable "aks_spot_enabled" {
  description = "Optional spot pool for burst/batch workloads in prod."
  type        = bool
  default     = true
}

variable "aks_sku_tier" {
  description = "Standard adds the AKS uptime SLA."
  type        = string
  default     = "Standard"
}
