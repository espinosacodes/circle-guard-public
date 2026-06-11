## =====================================================================
##  OCI VM — Always-Free AMD micro running a Docker host with a
##  CircleGuard edge service.
##
##  Used to satisfy Bonus 1 (multi-cloud) when OKE worker capacity is
##  unavailable in sa-bogota-1: we still get a *live workload* on OCI,
##  reachable over the public Internet, on a shape that has its own
##  separate quota (AMD E2.1.Micro is unaffected by Ampere capacity
##  issues).
##
##  Quota note: 2 VM.Standard.E2.1.Micro instances are Always Free per
##  tenancy. This module deploys 1 — leaving headroom.
## =====================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0"
    }
  }
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

locals {
  name_prefix = "${var.project_prefix}-${var.env}"

  default_freeform_tags = {
    env        = var.env
    project    = var.project_prefix
    managed-by = "terraform"
    component  = "edge-vm"
  }

  # cloud-init: install docker, run an nginx container with a custom
  # CircleGuard landing page that proves we're running on OCI.
  cloud_init = <<-CLOUDCFG
    #cloud-config
    package_update: true
    package_upgrade: false
    write_files:
      - path: /opt/circleguard/index.html
        permissions: '0644'
        content: |
          <!doctype html>
          <html lang="en">
          <head>
            <meta charset="utf-8">
            <title>CircleGuard — OCI edge (sa-bogota-1)</title>
            <style>
              body { font-family: system-ui, sans-serif; max-width: 720px;
                     margin: 4em auto; padding: 2em; line-height: 1.5;
                     background:#f7f7f7; color:#222; }
              h1 { color:#c74634; }
              .badge { display:inline-block; padding:4px 12px;
                       border-radius: 14px; background:#28a745; color:#fff;
                       font-size: 14px; }
              code { background:#fff; padding: 2px 6px; border-radius: 4px;
                     border: 1px solid #ddd; font-size: 13px; }
              table { border-collapse: collapse; width: 100%; margin: 1em 0; }
              th, td { text-align: left; padding: 6px 10px;
                       border-bottom: 1px solid #ddd; }
            </style>
          </head>
          <body>
            <span class="badge">LIVE on OCI</span>
            <h1>🛡️ CircleGuard — Edge Node</h1>
            <p>Multi-cloud bonus deliverable for IngeSoft V.
               This page is served by an Always-Free
               <code>VM.Standard.E2.1.Micro</code> instance in
               <code>sa-bogota-1</code>, behind the same VCN as the
               OKE control plane (<code>circleguard-stage-oke</code>).</p>
            <table>
              <tr><th>Region</th><td>sa-bogota-1 (Bogotá)</td></tr>
              <tr><th>Shape</th><td>VM.Standard.E2.1.Micro · 1 OCPU / 1 GB · AMD</td></tr>
              <tr><th>OS</th><td>Oracle Linux 8.10</td></tr>
              <tr><th>Container</th><td>nginx (via Docker)</td></tr>
              <tr><th>Tier</th><td>Always Free — $0/mo</td></tr>
            </table>
            <p>Primary cloud: GCP (GKE, us-central1).
               Secondary cloud: this OCI node.
               See <code>docs/MULTICLOUD_OCI.md</code> for the full topology
               and DR strategy.</p>
            <p><small>Endpoint health is checked by external-DNS for
               cross-cloud traffic shifting.</small></p>
          </body>
          </html>
    runcmd:
      - dnf install -y docker
      - systemctl enable --now docker
      - docker run -d --name circleguard-edge --restart unless-stopped
          -p 80:80
          -v /opt/circleguard/index.html:/usr/share/nginx/html/index.html:ro
          nginx:1.27-alpine
      # Open the host firewall — security list already permits TCP/80
      - firewall-cmd --permanent --add-port=80/tcp
      - firewall-cmd --reload
  CLOUDCFG
}

resource "oci_core_instance" "edge" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  shape               = "VM.Standard.E2.1.Micro"
  display_name        = "${local.name_prefix}-edge"

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = true
    hostname_label   = "${local.name_prefix}-edge"
    freeform_tags    = local.default_freeform_tags
  }

  source_details {
    source_type             = "image"
    source_id               = var.image_id
    boot_volume_size_in_gbs = 50
  }

  metadata = {
    user_data = base64encode(local.cloud_init)
  }

  freeform_tags = local.default_freeform_tags

  # The cloud-init runcmd phase finishes after ~2 minutes; OCI marks the
  # instance RUNNING once VNIC + boot are done, not once cloud-init is.
  # Downstream consumers should poll http://<public_ip>/ until 200.
}
