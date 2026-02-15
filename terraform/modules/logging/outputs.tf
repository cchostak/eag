output "log_bucket_id" {
  value = var.use_default_logging_bucket || !var.enable_exports ? "_Default" : google_logging_project_bucket_config.audit[0].bucket_id
}

output "archive_bucket" {
  value = var.enable_exports ? google_storage_bucket.archive[0].name : ""
}
