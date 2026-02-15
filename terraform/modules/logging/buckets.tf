resource "google_logging_project_bucket_config" "audit" {
  count          = var.enable_exports && !var.use_default_logging_bucket ? 1 : 0
  project        = var.project_id
  location       = var.log_bucket_location
  bucket_id      = local.log_bucket_id
  retention_days = var.retention_days
}

resource "google_storage_bucket" "archive" {
  count                       = var.enable_exports ? 1 : 0
  name                        = local.archive_bucket_name
  location                    = var.archive_bucket_location
  uniform_bucket_level_access = true
  force_destroy               = false
  project                     = var.project_id
  storage_class               = "STANDARD"
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = var.archive_retention_days
    }
    action {
      type = "Delete"
    }
  }
}
