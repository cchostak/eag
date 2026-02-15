locals {
  log_bucket_id        = "eag-audit-logs"
  archive_bucket_name  = var.archive_bucket_name != "" ? var.archive_bucket_name : lower(replace("${var.project_id}-eag-log-archive", "_", "-"))
  effective_log_filter = var.log_filter != "" ? var.log_filter : "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\""
}
