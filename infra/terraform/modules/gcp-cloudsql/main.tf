terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }
}

locals {
  name_prefix = "${var.project_prefix}-${var.env}"

  default_labels = {
    env        = var.env
    project    = var.project_prefix
    managed-by = "terraform"
  }
}

# Suffix avoids name collisions if you delete and recreate within 7 days
# (Cloud SQL keeps instance names reserved).
resource "random_id" "suffix" {
  byte_length = 2
}

resource "google_sql_database_instance" "this" {
  name             = "${local.name_prefix}-pg-${random_id.suffix.hex}"
  database_version = var.database_version
  region           = var.region

  deletion_protection = var.deletion_protection

  depends_on = [var.private_service_connection_id]

  settings {
    tier              = var.tier
    availability_type = var.availability_type
    disk_size         = var.disk_size_gb
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = var.pitr_enabled
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = var.retained_backups
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.network
      enable_private_path_for_google_cloud_services = true
    }

    maintenance_window {
      day          = 7 # Sunday
      hour         = 4
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = true
      record_application_tags = true
      record_client_address   = false
    }

    user_labels = local.default_labels
  }
}

resource "random_password" "app_user" {
  length           = 24
  special          = true
  override_special = "!@#%^*()-_=+"
}

resource "google_sql_user" "app" {
  name     = var.app_db_user
  instance = google_sql_database_instance.this.name
  password = random_password.app_user.result
}

resource "google_sql_database" "app" {
  name     = var.app_db_name
  instance = google_sql_database_instance.this.name
}
