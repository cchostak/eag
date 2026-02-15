module "monitoring" {
  source = "../../modules/monitoring"

  project_id         = var.project_id
  notification_email = var.notification_email
  service_name       = "eag-gateway"
  name_suffix        = var.name_suffix

  depends_on = [google_project_service.apis]
}
