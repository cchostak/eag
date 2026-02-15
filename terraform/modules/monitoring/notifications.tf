locals {
  notification_channels = var.notification_email == "" ? [] : [google_monitoring_notification_channel.email[0].id]
}

resource "google_monitoring_notification_channel" "email" {
  count        = var.notification_email == "" ? 0 : 1
  display_name = "EAG Alerts Email"
  type         = "email"
  project      = var.project_id

  labels = {
    email_address = var.notification_email
  }
}
