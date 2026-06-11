terraform {
  required_version = ">= 1.5"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0"
    }
  }
}

locals {
  name_prefix = "${var.project_prefix}-${var.env}"

  default_freeform_tags = {
    env        = var.env
    project    = var.project_prefix
    managed-by = "terraform"
  }
}

# --- VCN ---
# Single VCN per env, mirroring the Azure VNet pattern. CIDR comes from the
# env tfvars so dev/stage/prod never overlap.
resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${local.name_prefix}-vcn"
  # OCI VCN dns_label is alphanumeric, max 15 chars. Truncate to be safe
  # since "${project_prefix}${env}" can exceed 15 chars (e.g. "circleguardstage").
  dns_label = substr(replace(replace("${var.project_prefix}${var.env}", "-", ""), "_", ""), 0, 15)
  freeform_tags = local.default_freeform_tags
}

# --- Internet Gateway (for public subnet egress) ---
resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name_prefix}-igw"
  enabled        = true
  freeform_tags  = local.default_freeform_tags
}

# --- NAT Gateway (for private subnet egress) ---
resource "oci_core_nat_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name_prefix}-nat"
  freeform_tags  = local.default_freeform_tags
}

# --- Service Gateway (private access to OCI services: OCIR, Object Storage) ---
data "oci_core_services" "all_oci_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

resource "oci_core_service_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name_prefix}-svcgw"
  freeform_tags  = local.default_freeform_tags

  services {
    service_id = data.oci_core_services.all_oci_services.services[0].id
  }
}

# --- Route tables ---
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name_prefix}-rt-public"
  freeform_tags  = local.default_freeform_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name_prefix}-rt-private"
  freeform_tags  = local.default_freeform_tags

  # Default egress through the NAT gateway
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.this.id
  }

  # Pull images from OCIR and reach Object Storage without crossing the public internet
  route_rules {
    destination       = data.oci_core_services.all_oci_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.this.id
  }
}

# --- Security lists ---
# Public subnet: allow 443/80 inbound for the public LB, all egress.
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name_prefix}-sl-public"
  freeform_tags  = local.default_freeform_tags

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }
}

# Private subnet: only allow traffic from inside the VCN; egress to anywhere
# (NAT GW + Service GW will route accordingly).
resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name_prefix}-sl-private"
  freeform_tags  = local.default_freeform_tags

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "all"
    source   = var.vcn_cidr
  }
}

# --- Subnets ---
# Public: hosts the OCI LB for the OKE cluster (mirrors Azure appgw subnet).
resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = "${local.name_prefix}-public-subnet"
  dns_label                  = "pub"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  freeform_tags              = local.default_freeform_tags
}

# Private: hosts OKE worker nodes (mirrors Azure aks subnet).
resource "oci_core_subnet" "private" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.private_subnet_cidr
  display_name               = "${local.name_prefix}-private-subnet"
  dns_label                  = "priv"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  freeform_tags              = local.default_freeform_tags
}
