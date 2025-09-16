terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.60.0"
    }
  }
}

provider "google" {
  credentials = file("account.json")    # Service account JSON
  project     = var.project_id
  region      = var.region
}

resource "google_storage_bucket" "app_bucket" {
  name     = "${var.project_id}-bucket"
  location = var.region
}

resource "google_sql_database_instance" "main" {
  name             = "ticket-db"
  region           = var.region
  database_version = "POSTGRES_13"

  settings {
    tier = "db-f1-micro"
    backup_configuration {
      enabled = true
    }
  }
}

resource "google_sql_user" "default" {
  name     = "postgres"
  instance = google_sql_database_instance.main.name
  password = var.db_password
}

resource "google_sql_database" "appdb" {
  name     = "appdb"
  instance = google_sql_database_instance.main.name
}

resource "google_cloud_run_service" "frontend" {
  name     = "bookmyshow-frontend"
  location = var.region

  template {
    spec {
      containers {
        image = var.frontend_image
        env {
          name  = "API_URL"
          value = var.api_url
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service" "api" {
  name     = "bookmyshow-api"
  location = var.region

  template {
    spec {
      containers {
        image = var.api_image
        env {
          name  = "DB_HOST"
          value = google_sql_database_instance.main.public_ip_address
        }
        env {
          name  = "DB_NAME"
          value = google_sql_database.appdb.name
        }
        env {
          name  = "DB_USER"
          value = google_sql_user.default.name
        }
        env {
          name  = "DB_PASS"
          value = var.db_password
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service_iam_member" "all_users_frontend" {
  service    = google_cloud_run_service.frontend.name
  location   = google_cloud_run_service.frontend.location
  role       = "roles/run.invoker"
  member     = "allUsers"
}

resource "google_cloud_run_service_iam_member" "all_users_api" {
  service    = google_cloud_run_service.api.name
  location   = google_cloud_run_service.api.location
  role       = "roles/run.invoker"
  member     = "allUsers"
}
