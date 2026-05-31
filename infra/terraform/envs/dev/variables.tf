variable "gcp_project_id" {
  description = "GCP project ID for the dev environment."
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
  default     = "dev"
}

# --- Network ---
variable "subnet_cidr" {
  description = "Primary CIDR for the GKE node subnet."
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR for GKE pods."
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR for GKE services."
  type        = string
  default     = "10.30.0.0/20"
}

# --- GKE ---
variable "gke_machine_type" {
  description = "Node machine type."
  type        = string
  default     = "e2-standard-2"
}

variable "gke_node_count_min" {
  description = "Min nodes per zone."
  type        = number
  default     = 1
}

variable "gke_node_count_max" {
  description = "Max nodes per zone."
  type        = number
  default     = 3
}

variable "gke_preemptible" {
  description = "Run GKE primary pool on spot VMs."
  type        = bool
  default     = true
}

# --- CloudSQL ---
variable "cloudsql_tier" {
  description = "Cloud SQL machine tier."
  type        = string
  default     = "db-f1-micro"
}
