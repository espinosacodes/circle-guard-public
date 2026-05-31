variable "project_prefix" {
  description = "Short project prefix; e.g. circleguard."
  type        = string
  default     = "circleguard"
}

variable "env" {
  description = "Environment name (dev, stage, prod)."
  type        = string
}

variable "region" {
  description = "Region for the Cloud SQL instance."
  type        = string
}

variable "network" {
  description = "VPC self-link the instance attaches to via private IP."
  type        = string
}

variable "private_service_connection_id" {
  description = "ID of google_service_networking_connection from gcp-network. Forces correct ordering."
  type        = string
}

variable "database_version" {
  description = "Cloud SQL database version."
  type        = string
  default     = "POSTGRES_16"
}

variable "tier" {
  description = "Machine tier. db-f1-micro for dev, db-custom-* for prod."
  type        = string
  default     = "db-f1-micro"
}

variable "availability_type" {
  description = "ZONAL (cheap) or REGIONAL (HA, ~2x cost)."
  type        = string
  default     = "ZONAL"
}

variable "disk_size_gb" {
  description = "Initial disk size in GiB. Auto-resize is on."
  type        = number
  default     = 10
}

variable "pitr_enabled" {
  description = "Enable point-in-time recovery (Postgres write-ahead logs)."
  type        = bool
  default     = true
}

variable "retained_backups" {
  description = "How many backups to keep."
  type        = number
  default     = 7
}

variable "app_db_name" {
  description = "Initial application database to create."
  type        = string
  default     = "circleguard"
}

variable "app_db_user" {
  description = "Initial application DB user."
  type        = string
  default     = "circleguard_app"
}

variable "deletion_protection" {
  description = "If true, Terraform cannot destroy the instance."
  type        = bool
  default     = true
}
