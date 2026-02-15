locals {
  log_bucket_id        = "eag-audit-logs"
  archive_bucket_name  = var.archive_bucket_name != "" ? var.archive_bucket_name : lower(replace("${var.project_id}-eag-log-archive${var.name_suffix}", "_", "-"))
  effective_log_filter = var.log_filter != "" ? var.log_filter : "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\""
  audit_bucket_destination = (
    var.use_default_logging_bucket
    ? "logging.googleapis.com/projects/${var.project_id}/locations/global/buckets/_Default"
    : "logging.googleapis.com/projects/${var.project_id}/locations/${var.log_bucket_location}/buckets/${local.log_bucket_id}"
  )
}
