output "cluster_id" {
  description = "OKE cluster OCID."
  value       = oci_containerengine_cluster.this.id
}

output "cluster_name" {
  description = "OKE cluster display name."
  value       = oci_containerengine_cluster.this.name
}

output "kubernetes_version" {
  description = "Kubernetes version running on the OKE control plane."
  value       = oci_containerengine_cluster.this.kubernetes_version
}

output "node_pool_id" {
  description = "OCID of the worker node pool."
  value       = oci_containerengine_node_pool.workers.id
}

output "get_kubeconfig_cmd" {
  description = "oci CLI command that materialises the kubeconfig for kubectl."
  value       = "oci ce cluster create-kubeconfig --cluster-id ${oci_containerengine_cluster.this.id} --file $HOME/.kube/config --region ${var.region_for_kubeconfig} --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT"
}
