module "monitoring" {
  source = "../../modules/monitoring"

  project_id            = var.project_id
  notification_email    = var.notification_email
  service_name          = "eag-gateway"
  name_suffix           = var.name_suffix
  create_auth_metric    = var.create_auth_metric
  create_auth_alert     = var.create_auth_alert
  create_custom_service = var.create_custom_service

  depends_on = [google_project_service.apis]
}
