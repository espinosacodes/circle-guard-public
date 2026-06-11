output "vcn_id" {
  description = "ID of the VCN."
  value       = oci_core_vcn.this.id
}

output "vcn_name" {
  description = "Display name of the VCN."
  value       = oci_core_vcn.this.display_name
}

output "public_subnet_id" {
  description = "Subnet ID for the OCI load balancer."
  value       = oci_core_subnet.public.id
}

output "private_subnet_id" {
  description = "Subnet ID for OKE worker nodes."
  value       = oci_core_subnet.private.id
}

output "internet_gateway_id" {
  description = "Internet Gateway OCID."
  value       = oci_core_internet_gateway.this.id
}

output "nat_gateway_id" {
  description = "NAT Gateway OCID."
  value       = oci_core_nat_gateway.this.id
}

output "service_gateway_id" {
  description = "Service Gateway OCID (private route to OCIR / Object Storage)."
  value       = oci_core_service_gateway.this.id
}
