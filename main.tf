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
  project     = var.project_id
  region      = var.region
  credentials = file("creds.json")
}

# Cloud Storage static website bucket and objects
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
  members = ["allUsers"]
}

resource "google_storage_bucket_object" "index_html" {
  name         = "index.html"
  bucket       = google_storage_bucket.bookmyshow_site.name
  source       = "${path.module}/site/index.html"
  content_type = "text/html"
}

resource "google_storage_bucket_object" "styles_css" {
  name         = "styles.css"
  bucket       = google_storage_bucket.bookmyshow_site.name
  source       = "${path.module}/site/styles.css"
  content_type = "text/css"
}

resource "google_storage_bucket_object" "script_js" {
  name         = "script.js"
  bucket       = google_storage_bucket.bookmyshow_site.name
  source       = "${path.module}/site/script.js"
  content_type = "application/javascript"
}

# Cloud SQL Primary Instance
resource "google_sql_database_instance" "primary" {
  name             = "bookmyshow-primary"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = "db-custom-2-7680" # 2 vCPU, 7.5GB RAM

    backup_configuration {
      enabled                      = true
      point_in_time_recovery_enabled = true
      start_time                  = "02:00"
      location                    = var.region
    }

    availability_type = "REGIONAL"

    ip_configuration {
      ipv4_enabled    = false
      private_network = data.google_compute_network.vpc_network.self_link
    }
  }

  deletion_protection = false
}

# Cloud SQL Read Replica
resource "google_sql_database_instance" "read_replica" {
  name                = "bookmyshow-read-replica"
  region              = var.region
  database_version    = google_sql_database_instance.primary.database_version
  master_instance_name = google_sql_database_instance.primary.name

  settings {
    tier = "db-custom-2-7680"

    ip_configuration {
      ipv4_enabled    = false
      private_network = data.google_compute_network.vpc_network.self_link
    }
  }
}

resource "google_sql_database" "bookmyshow_db" {
  name     = "bookmyshowdb"
  instance = google_sql_database_instance.primary.name
  charset  = "UTF8"
  collation = "en_US.UTF8"
}

# Compute Engine Instance Template
resource "google_compute_instance_template" "app_template" {
  name         = "bookmyshow-instance-template"
  machine_type = "e2-medium"

  disk {
    boot         = true
    auto_delete  = true
    source_image = "projects/debian-cloud/global/images/family/debian-11"
  }

  network_interface {
    network      = "default"
    access_config {}
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
  EOT
}

# Regional MIG
resource "google_compute_region_instance_group_manager" "mig" {
  name               = "bookmyshow-mig"
  region             = var.region
  base_instance_name = "bookmyshow-instance"
  target_size        = 1

  version {
    instance_template = google_compute_instance_template.app_template.id
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.http_health_check.id
    initial_delay_sec = 300
  }
}

# Regional Autoscaler for MIG
resource "google_compute_region_autoscaler" "mig_autoscaler" {
  name    = "bookmyshow-autoscaler"
  region  = var.region
  project = var.project_id

  target = google_compute_region_instance_group_manager.mig.id

  autoscaling_policy {
    min_replicas = 1
    max_replicas = 5

    cpu_utilization {
      target = 0.6
    }
  }
}

# Health Check
resource "google_compute_health_check" "http_health_check" {
  name                 = "bookmyshow-http-health-check"
  check_interval_sec   = 10
  timeout_sec          = 5
  healthy_threshold    = 2
  unhealthy_threshold  = 2

  http_health_check {
    port         = 80
    request_path = "/"
  }
}

# Backend Service for MIG
resource "google_compute_backend_service" "mig_backend" {
  name          = "bookmyshow-backend"
  protocol      = "HTTP"
  port_name     = "http"
  timeout_sec   = 30
  health_checks = [google_compute_health_check.http_health_check.id]

  backend {
    group = google_compute_region_instance_group_manager.mig.instance_group
  }
}

# Cloud Run Service for API
resource "google_cloud_run_service" "api" {
  name     = "bookmyshow-api"
  location = var.region

  template {
    spec {
      containers {
        image = var.api_image
        ports {
          container_port = 8080
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Cloud Run Invoker IAM Binding
resource "google_cloud_run_service_iam_member" "api_invoker" {
  location = google_cloud_run_service.api.location
  project  = var.project_id
  service  = google_cloud_run_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Serverless NEG for Cloud Run
resource "google_compute_region_network_endpoint_group" "cloud_run_neg" {
  name                  = "cloud-run-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_service.api.name
  }
}

# Backend Service for Cloud Run NEG
resource "google_compute_backend_service" "cloud_run_backend" {
  name          = "bookmyshow-cloudrun-backend"
  protocol      = "HTTP"
  timeout_sec   = 30
  enable_cdn    = true

  backend {
    group = google_compute_region_network_endpoint_group.cloud_run_neg.id
  }
}

# URL Map for Load Balancer
resource "google_compute_url_map" "url_map" {
  name           = "bookmyshow-url-map"
  default_service = google_compute_backend_service.mig_backend.id

  host_rule {
    hosts       = ["*"]
    path_matcher = "default-path-matcher"
  }

  path_matcher {
    name           = "default-path-matcher"
    default_service = google_compute_backend_service.mig_backend.id

    path_rule {
      paths   = ["/api/*"]
      service = google_compute_backend_service.cloud_run_backend.id
    }
  }
}

# HTTP Proxy
resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "bookmyshow-http-proxy"
  url_map = google_compute_url_map.url_map.id
}

# Global Forwarding Rule
resource "google_compute_global_forwarding_rule" "http_forwarding" {
  name                  = "bookmyshow-http-forwarding"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.http_proxy.id
  ip_protocol           = "TCP"
}

# Get the default VPC self-link for private IP subnetworks
data "google_compute_network" "vpc_network" {
  name    = "default"
  project = var.project_id
}
