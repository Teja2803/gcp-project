output "frontend_url" {
  value       = google_cloud_run_service.frontend.status.url
  description = "Deployed Frontend URL"
}

output "api_url" {
  value       = google_cloud_run_service.api.status.url
  description = "Deployed API URL"
}

output "sql_instance_ip" {
  value       = google_sql_database_instance.main.public_ip_address
  description = "Cloud SQL Public IP"
}
