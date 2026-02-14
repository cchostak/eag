# monitoring module - Alerting, dashboards, SLOs

variable "project_id" {
  type = string
}

variable "notification_email" {
  type        = string
  description = "Email for alerts"
}

variable "service_name" {
  type    = string
  default = "eag-gateway"
}

# Log-based metric for authorization denials
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

# --- Notification Channel ---

resource "google_monitoring_notification_channel" "email" {
  display_name = "EAG Alerts Email"
  type         = "email"
  project      = var.project_id

  labels = {
    email_address = var.notification_email
  }
}

# --- Alert Policies ---

# High error rate
resource "google_monitoring_alert_policy" "high_error_rate" {
  display_name = "EAG - High Error Rate"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Error rate > 5%"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.05

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  alert_strategy {
    auto_close = "86400s" # 24 hours
  }

  documentation {
    content = <<-EOT
      Error rate exceeded 5%. Check Cloud Run logs and upstream MCP servers.

      Runbook: https://github.com/yourorg/eag/docs/runbooks/high-error-rate.md
    EOT
  }
}

# High latency
resource "google_monitoring_alert_policy" "high_latency" {
  display_name = "EAG - High Latency"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "p95 latency > 2s"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\" AND metric.type=\"run.googleapis.com/request_latencies\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 2000 # 2 seconds in ms

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}

# Security: High authorization denial rate
resource "google_monitoring_alert_policy" "security_denials" {
  display_name = "EAG - High Authorization Denials"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Authorization denials > 10/min"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/eag-auth-denials\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 10

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  documentation {
    content = <<-EOT
      High rate of authorization denials detected. Possible attack or misconfiguration.

      Check: gcloud logging read 'jsonPayload.message=~"denied"' --limit 50
    EOT
  }
}

# Instance down
resource "google_monitoring_alert_policy" "instance_down" {
  display_name = "EAG - No Healthy Instances"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "No healthy instances"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\" AND metric.type=\"run.googleapis.com/container/instance_count\""
      duration        = "180s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}

# --- SLO Definition (99.9% availability) ---

resource "google_monitoring_slo" "availability" {
  service      = google_monitoring_custom_service.eag.service_id
  slo_id       = "eag-availability-slo"
  display_name = "99.9% Availability"
  project      = var.project_id

  goal                = 0.999
  rolling_period_days = 30

  request_based_sli {
    good_total_ratio {
      total_service_filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\""
      good_service_filter  = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\" AND metric.labels.response_code_class!=\"5xx\""
    }
  }
}

resource "google_monitoring_custom_service" "eag" {
  service_id   = "eag-gateway-service"
  display_name = "EAG Gateway"
  project      = var.project_id
}

# --- Dashboard ---

resource "google_monitoring_dashboard" "eag" {
  dashboard_json = jsonencode({
    displayName = "EAG Gateway Dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Request Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\" AND metric.type=\"run.googleapis.com/request_count\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          widget = {
            title = "Error Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          width  = 12
          height = 4
          yPos   = 4
          widget = {
            title = "Latency (p50, p95, p99)"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\" AND metric.type=\"run.googleapis.com/request_latencies\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        crossSeriesReducer = "REDUCE_PERCENTILE_50"
                      }
                    }
                  }
                  plotType = "LINE"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\" AND metric.type=\"run.googleapis.com/request_latencies\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        crossSeriesReducer = "REDUCE_PERCENTILE_95"
                      }
                    }
                  }
                  plotType = "LINE"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\" AND metric.type=\"run.googleapis.com/request_latencies\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        crossSeriesReducer = "REDUCE_PERCENTILE_99"
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
            }
          }
        }
      ]
    }
  })
}

# --- Outputs ---

output "dashboard_url" {
  value = "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.eag.id}?project=${var.project_id}"
}
