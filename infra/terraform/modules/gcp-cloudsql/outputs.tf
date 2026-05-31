output "instance_name" {
  description = "Cloud SQL instance name."
  value       = google_sql_database_instance.this.name
}

output "instance_connection_name" {
  description = "Cloud SQL connection name (project:region:instance) for the proxy."
  value       = google_sql_database_instance.this.connection_name
}

output "private_ip_address" {
  description = "Private IP of the instance."
  value       = google_sql_database_instance.this.private_ip_address
}

output "app_db_name" {
  description = "Name of the application database."
  value       = google_sql_database.app.name
}

output "app_db_user" {
  description = "Application DB user name."
  value       = google_sql_user.app.name
}

output "app_db_password" {
  description = "Generated application DB password. Store in Secret Manager."
  value       = random_password.app_user.result
  sensitive   = true
}
