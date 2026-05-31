variable "gcp_project_id" {
  description = "GCP project ID that will own the Terraform state bucket."
  type        = string
}

variable "gcp_region" {
  description = "Region the GCS state bucket is created in."
  type        = string
  default     = "us-central1"
}

variable "project_prefix" {
  description = "Short project prefix used in resource naming."
  type        = string
  default     = "circleguard"
}

variable "state_bucket_name" {
  description = "Optional explicit bucket name. If null, the module derives one from project_prefix + gcp_project_id."
  type        = string
  default     = null
}
