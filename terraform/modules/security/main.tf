# security module - IAM, Secret Manager, service accounts

variable "project_id" {
  type = string
}

variable "config_yaml_path" {
  type        = string
  description = "Path to the config.yaml to store in Secret Manager"
}

variable "api_keys" {
  type        = map(string)
  description = "Map of secret name => value for API keys"
  default     = {}
  sensitive   = true
}

# --- Service Account for Cloud Run ---

resource "google_service_account" "eag" {
  account_id   = "eag-gateway"
  display_name = "EAG Gateway Service Account"
  project      = var.project_id
}

# Allow Cloud Run SA to read secrets
resource "google_project_iam_member" "secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.eag.email}"
}

# Allow Cloud Run SA to write traces
resource "google_project_iam_member" "trace_agent" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.eag.email}"
}

# Allow Cloud Run SA to write logs
resource "google_project_iam_member" "log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.eag.email}"
}

# Allow Cloud Run SA to write metrics
resource "google_project_iam_member" "metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.eag.email}"
}

# --- Secret Manager: Gateway Config ---

resource "google_secret_manager_secret" "config" {
  secret_id = "eag-gateway-config"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "config" {
  secret      = google_secret_manager_secret.config.id
  secret_data = file(var.config_yaml_path)
}

# --- Secret Manager: API Keys ---

resource "google_secret_manager_secret" "api_keys" {
  for_each = var.api_keys

  secret_id = "eag-${each.key}"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "api_keys" {
  for_each = var.api_keys

  secret      = google_secret_manager_secret.api_keys[each.key].id
  secret_data = each.value
}

# --- Outputs ---

output "service_account_email" {
  value = google_service_account.eag.email
}

output "config_secret_id" {
  value = google_secret_manager_secret.config.secret_id
}

output "api_key_secret_ids" {
  value = {
    for name, secret in google_secret_manager_secret.api_keys :
    name => secret.secret_id
  }
}
