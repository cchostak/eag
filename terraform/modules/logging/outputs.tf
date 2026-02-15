output "log_bucket_id" {
  value = var.use_default_logging_bucket ? "_Default" : google_logging_project_bucket_config.audit[0].bucket_id
}

output "archive_bucket" {
  value = google_storage_bucket.archive.name
}
