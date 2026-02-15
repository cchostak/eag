resource "google_logging_metric" "auth_denials" {
  name        = "eag-auth-denials"
  description = "Counts authorization denials for the EAG gateway"
  project     = var.project_id

  filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\" AND jsonPayload.message=~\"denied|blocked|unauthorized\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}
