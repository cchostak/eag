resource "google_logging_project_sink" "to_logging_bucket" {
  name                   = "eag-to-logging-bucket"
  project                = var.project_id
  destination            = "logging.googleapis.com/projects/${var.project_id}/locations/${var.log_bucket_location}/buckets/${google_logging_project_bucket_config.audit.bucket_id}"
  filter                 = "(${local.effective_log_filter}) OR logName:\"projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity\""
  unique_writer_identity = true
}

resource "google_logging_project_bucket_iam_member" "sink_writer" {
  project  = var.project_id
  bucket   = google_logging_project_bucket_config.audit.bucket_id
  role     = "roles/logging.bucketWriter"
  member   = google_logging_project_sink.to_logging_bucket.writer_identity
}

resource "google_logging_project_sink" "to_archive" {
  name                   = "eag-to-archive"
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
