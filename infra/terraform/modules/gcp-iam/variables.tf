variable "project_prefix" {
  description = "Short project prefix; e.g. circleguard."
  type        = string
  default     = "circleguard"
}

variable "env" {
  description = "Environment name."
  type        = string
}

variable "gcp_project_id" {
  description = "GCP project ID hosting the cluster."
  type        = string
}

variable "workload_identity_bindings" {
  description = <<-EOT
    List of Workload Identity bindings. Each entry creates a GSA and
    binds it to a Kubernetes ServiceAccount in the given namespace.
    'roles' is a list of project-level IAM roles to grant the GSA.
  EOT
  type = list(object({
    k8s_namespace = string
    k8s_sa        = string
    roles         = list(string)
  }))
  default = []
}

variable "create_workload_identity_pool_bindings" {
  description = "Create Kubernetes-to-GSA bindings. Disable when the GKE identity pool is created in the same root module and bind after the cluster exists."
  type        = bool
  default     = true
}
