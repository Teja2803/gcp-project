variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region (e.g. us-central1)"
  default     = "us-central1"
}

variable "frontend_image" {
  type        = string
  description = "Frontend application Docker image (e.g. gcr.io/my-project/frontend:tag)"
}

variable "api_image" {
  type        = string
  description = "API backend Docker image (e.g. gcr.io/my-project/api:tag)"
}

variable "db_password" {
  type        = string
  description = "Password for Cloud SQL user"
  sensitive   = true
}

variable "api_url" {
  type        = string
  description = "API service URL (set in frontend's environment)"
}
