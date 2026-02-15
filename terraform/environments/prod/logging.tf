module "logging" {
  source = "../../modules/logging"

  project_id          = var.project_id
  service_name        = "eag-gateway"
  retention_days      = var.log_retention_days
  archive_bucket_name = var.log_archive_bucket
  name_suffix         = var.name_suffix
  enable_exports      = var.enable_exports

  depends_on = [google_project_service.apis]
}
