resource "google_monitoring_notification_channel" "email" {
  display_name = "EAG Alerts Email"
  type         = "email"
  project      = var.project_id

  labels = {
    email_address = var.notification_email
  }
}
