terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.60.0"
    }
  }
  required_version = ">= 1.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
  credentials = file("creds.json")
}

resource "google_storage_bucket" "bookmyshow_site" {
  name          = "${var.project_id}-bookmyshow-site"
  location      = var.region
  force_destroy = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }
}

resource "google_storage_bucket_iam_binding" "public_read" {
  bucket = google_storage_bucket.bookmyshow_site.name
  role   = "roles/storage.objectViewer"
  members = [
    "allUsers",
  ]
}

resource "google_storage_bucket_object" "index_html" {
  name   = "index.html"
  bucket = google_storage_bucket.bookmyshow_site.name
  source = "${path.module}/site/index.html"
  content_type = "text/html"
}

resource "google_storage_bucket_object" "styles_css" {
  name   = "styles.css"
  bucket = google_storage_bucket.bookmyshow_site.name
  source = "${path.module}/site/styles.css"
  content_type = "text/css"
}

resource "google_storage_bucket_object" "script_js" {
  name   = "script.js"
  bucket = google_storage_bucket.bookmyshow_site.name
  source = "${path.module}/site/script.js"
  content_type = "application/javascript"
}

output "site_url" {
  value       = "http://${google_storage_bucket.bookmyshow_site.name}.storage.googleapis.com/index.html"
  description = "URL for the deployed BookMyShow static site"
}
