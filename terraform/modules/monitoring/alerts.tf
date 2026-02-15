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

  notification_channels = local.notification_channels

  alert_strategy {
    auto_close = "86400s"
  }

  documentation {
    content = <<-EOT
      Error rate exceeded 5%. Check Cloud Run logs and upstream MCP servers.

      Runbook: https://github.com/yourorg/eag/docs/runbooks/high-error-rate.md
    EOT
  }
}

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
      threshold_value = 2000

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
      }
    }
  }

  notification_channels = local.notification_channels
}

resource "google_monitoring_alert_policy" "security_denials" {
  display_name = "EAG - High Authorization Denials"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Authorization denials > 10/min"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/eag-auth-denials${var.name_suffix}\" AND resource.type=\"global\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 10

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = local.notification_channels

  documentation {
    content = <<-EOT
      High rate of authorization denials detected. Possible attack or misconfiguration.

      Check: gcloud logging read 'jsonPayload.message=~"denied"' --limit 50
    EOT
  }
}

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

  notification_channels = local.notification_channels
}
