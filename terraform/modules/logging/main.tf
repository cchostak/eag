# logging module - Audit log retention and archival

variable "project_id" {
  type = string
}

variable "service_name" {
  type    = string
  default = "eag-gateway"
}

variable "retention_days" {
  type    = number
  default = 365
}

variable "log_bucket_location" {
  type    = string
  default = "global"
}

variable "archive_bucket_name" {
  type        = string
  description = "Optional override for the GCS archive bucket name"
  default     = ""
}

variable "archive_bucket_location" {
  type    = string
  default = "us"
}

variable "archive_retention_days" {
  type    = number
  default = 1095 # 3 years
}

variable "log_filter" {
  type    = string
  default = ""
}

locals {
  log_bucket_id       = "eag-audit-logs"
  archive_bucket_name = var.archive_bucket_name != "" ? var.archive_bucket_name : lower(replace("${var.project_id}-eag-log-archive", "_", "-"))
  effective_log_filter = var.log_filter != "" ? var.log_filter : "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\""
}

# Dedicated Logging bucket with extended retention
resource "google_logging_project_bucket_config" "audit" {
  project        = var.project_id
  location       = var.log_bucket_location
  bucket_id      = local.log_bucket_id
  retention_days = var.retention_days
}

# Sink Cloud Run + audit logs into the dedicated bucket
resource "google_logging_sink" "to_logging_bucket" {
  name                   = "eag-to-logging-bucket"
  project                = var.project_id
  destination            = "logging.googleapis.com/projects/${var.project_id}/locations/${var.log_bucket_location}/buckets/${google_logging_project_bucket_config.audit.bucket_id}"
  filter                 = "(${local.effective_log_filter}) OR logName:\"projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity\""
  unique_writer_identity = true
  include_children       = false
}

resource "google_logging_project_bucket_config_iam_member" "sink_writer" {
  project = var.project_id
  location = var.log_bucket_location
  bucket  = google_logging_project_bucket_config.audit.bucket_id
  role    = "roles/logging.bucketWriter"
  member  = google_logging_sink.to_logging_bucket.writer_identity
}

# GCS archive bucket with versioning for long-term backup
resource "google_storage_bucket" "archive" {
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

resource "google_logging_sink" "to_archive" {
  name                   = "eag-to-archive"
  project                = var.project_id
  destination            = "storage.googleapis.com/${google_storage_bucket.archive.name}"
  filter                 = google_logging_sink.to_logging_bucket.filter
  unique_writer_identity = true
  include_children       = false
}

resource "google_storage_bucket_iam_member" "archive_writer" {
  bucket = google_storage_bucket.archive.name
  role   = "roles/storage.objectCreator"
  member = google_logging_sink.to_archive.writer_identity
}

output "log_bucket_id" {
  value = google_logging_project_bucket_config.audit.bucket_id
}

output "archive_bucket" {
  value = google_storage_bucket.archive.name
}
