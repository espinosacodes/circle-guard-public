output "instance_id" {
  description = "OCID of the edge VM."
  value       = oci_core_instance.edge.id
}

output "public_ip" {
  description = "Public IPv4 address of the edge VM. Reach the demo page at http://<public_ip>/."
  value       = oci_core_instance.edge.public_ip
}

output "demo_url" {
  description = "Convenience URL to hit during the live demo."
  value       = "http://${oci_core_instance.edge.public_ip}/"
}
