resource "google_logging_project_sink" "to_logging_bucket" {
  name                   = "eag-to-logging-bucket${var.name_suffix}"
  project                = var.project_id
  destination            = local.audit_bucket_destination
  filter                 = "(${local.effective_log_filter}) OR logName:\"projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity\""
  unique_writer_identity = true
}

resource "google_logging_project_sink" "to_archive" {
  name                   = "eag-to-archive${var.name_suffix}"
  project                = var.project_id
  destination            = "storage.googleapis.com/${google_storage_bucket.archive.name}"
  filter                 = google_logging_project_sink.to_logging_bucket.filter
  unique_writer_identity = true
}

resource "google_storage_bucket_iam_member" "archive_writer" {
  bucket = google_storage_bucket.archive.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.to_archive.writer_identity
}
