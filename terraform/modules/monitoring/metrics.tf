resource "google_logging_metric" "auth_denials" {
  count       = var.create_auth_metric ? 1 : 0
  name        = "eag-auth-denials${var.name_suffix}"
  description = "Counts authorization denials for the EAG gateway"
  project     = var.project_id

  filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\" AND jsonPayload.message=~\"denied|blocked|unauthorized\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}
