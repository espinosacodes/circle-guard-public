variable "project_prefix" {
  description = "Short project prefix; e.g. circleguard."
  type        = string
  default     = "circleguard"
}

variable "env" {
  description = "Environment name."
  type        = string
}

variable "compartment_id" {
  description = "OCI compartment OCID. Root compartment (tenancy OCID) is acceptable for the trial."
  type        = string
}

variable "tenancy_namespace" {
  description = "Object Storage namespace of the tenancy (e.g. axabcdefgh). Used to build the FQDN. Query with `oci os ns get`."
  type        = string
}

variable "region_key" {
  description = "OCIR region key, e.g. 'sa-bogota-1'. Forms the host: <region>.ocir.io."
  type        = string
}

variable "is_public" {
  description = "If true, repos are public (no auth to pull). Keep false in real environments."
  type        = bool
  default     = false
}

variable "service_names" {
  description = "List of microservice short names to create repos for."
  type        = list(string)
  default = [
    "gateway-service",
    "auth-service",
    "identity-service",
    "form-service",
    "promotion-service",
    "notification-service",
    "dashboard-service",
    "file-service",
  ]
}
