output "site_url" {
  description = "Static Website URL"
  value       = "http://${google_storage_bucket.bookmyshow_site.name}.storage.googleapis.com/index.html"
}

output "cloud_run_api_url" {
  description = "Cloud Run API Service URL"
  value       = google_cloud_run_service.api.status[0].url
}

output "load_balancer_ip" {
  description = "Global HTTP Load Balancer IPv4 Address"
  value       = google_compute_global_forwarding_rule.http_forwarding.ip_address
}

output "cloud_sql_primary_connection_name" {
  description = "Connection name for Cloud SQL primary instance"
  value       = google_sql_database_instance.primary.connection_name
}

output "cloud_sql_read_replica_connection_name" {
  description = "Connection name for Cloud SQL read replica"
  value       = google_sql_database_instance.read_replica.connection_name
}

output "cloud_sql_database_name" {
  description = "Cloud SQL database name"
  value       = google_sql_database.bookmyshow_db.name
}

output "mig_instance_group_name" {
  description = "Managed Instance Group name"
  value       = google_compute_region_instance_group_manager.mig.name
}

output "locust_load_test_url" {
  description = "URL for Locust load test UI (if deployed)"
  value       = google_cloud_run_service.locust.status[0].url
}
