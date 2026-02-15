resource "google_logging_project_sink" "to_logging_bucket" {
  count                  = var.enable_exports ? 1 : 0
  name                   = "eag-to-logging-bucket${var.name_suffix}"
  project                = var.project_id
  destination            = local.audit_bucket_destination
  filter                 = "(${local.effective_log_filter}) OR logName:\"projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity\""
  unique_writer_identity = true
}

resource "google_logging_project_sink" "to_archive" {
  count                  = var.enable_exports ? 1 : 0
  name                   = "eag-to-archive${var.name_suffix}"
  project                = var.project_id
  destination            = "storage.googleapis.com/${google_storage_bucket.archive[0].name}"
  filter                 = google_logging_project_sink.to_logging_bucket[0].filter
  unique_writer_identity = true
}

resource "google_storage_bucket_iam_member" "archive_writer" {
  count  = var.enable_exports ? 1 : 0
  bucket = google_storage_bucket.archive[0].name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.to_archive[0].writer_identity
}
