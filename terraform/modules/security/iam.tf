resource "google_service_account" "eag" {
  count        = var.existing_service_account_email == "" ? 1 : 0
  account_id   = "eag-gateway${replace(var.name_suffix, "-", "")}"
  display_name = "EAG Gateway Service Account${var.name_suffix}"
  project      = var.project_id
}

resource "google_project_iam_member" "secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${var.existing_service_account_email != "" ? var.existing_service_account_email : google_service_account.eag[0].email}"
}

resource "google_project_iam_member" "secret_version_adder" {
  project = var.project_id
  role    = "roles/secretmanager.secretVersionManager"
  member  = "serviceAccount:${var.existing_service_account_email != "" ? var.existing_service_account_email : google_service_account.eag[0].email}"
}

resource "google_project_iam_member" "trace_agent" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${var.existing_service_account_email != "" ? var.existing_service_account_email : google_service_account.eag[0].email}"
}

resource "google_project_iam_member" "log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${var.existing_service_account_email != "" ? var.existing_service_account_email : google_service_account.eag[0].email}"
}

resource "google_project_iam_member" "metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${var.existing_service_account_email != "" ? var.existing_service_account_email : google_service_account.eag[0].email}"
}
