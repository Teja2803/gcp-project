variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "GCP region for bucket location"
  type        = string
  default     = "us-central1"
}
