variable "project_prefix" {
  description = "Short project prefix; e.g. circleguard."
  type        = string
  default     = "circleguard"
}

variable "env" {
  description = "Environment name (dev, stage, prod)."
  type        = string
}

variable "gcp_project_id" {
  description = "GCP project ID hosting the cluster."
  type        = string
}

variable "region" {
  description = "Region for the regional GKE cluster."
  type        = string
}

variable "network" {
  description = "VPC self-link from gcp-network module."
  type        = string
}

variable "subnetwork" {
  description = "Subnet self-link from gcp-network module."
  type        = string
}

variable "pods_range_name" {
  description = "Name of the secondary range for pods."
  type        = string
}

variable "services_range_name" {
  description = "Name of the secondary range for services."
  type        = string
}

variable "release_channel" {
  description = "GKE release channel: RAPID, REGULAR, or STABLE."
  type        = string
  default     = "REGULAR"
}

variable "master_ipv4_cidr" {
  description = "Private master CIDR block (must be /28)."
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "List of CIDRs allowed to reach the public master endpoint."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "world (tighten me in prod!)"
    }
  ]
}

variable "node_count_min" {
  description = "Min nodes per zone in the autoscaler."
  type        = number
  default     = 1
}

variable "node_count_max" {
  description = "Max nodes per zone in the autoscaler."
  type        = number
  default     = 3
}

variable "machine_type" {
  description = "GCE machine type for the node pool."
  type        = string
  default     = "e2-standard-2"
}

variable "disk_size_gb" {
  description = "Node boot disk size in GiB."
  type        = number
  default     = 50
}

variable "preemptible" {
  description = "If true, run the primary pool on spot VMs (~70% cheaper, can be evicted)."
  type        = bool
  default     = true
}

variable "node_service_account" {
  description = "Service account email used by nodes. Pass null to use the default compute SA (not recommended for prod)."
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "If true, Terraform cannot destroy the cluster."
  type        = bool
  default     = false
}
