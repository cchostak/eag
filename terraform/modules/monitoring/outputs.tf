output "dashboard_url" {
  value = "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.eag.id}?project=${var.project_id}"
}
