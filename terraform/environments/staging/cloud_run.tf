module "cloud_run" {
  source = "../../modules/cloud-run"

  project_id            = var.project_id
  regions               = var.regions
  image                 = var.gateway_image
  config_secret_id      = module.security.config_secret_id
  service_account_email = module.security.service_account_email
  min_instances         = 0
  max_instances         = 3

  env_secrets = {
    for name, id in module.security.api_key_secret_ids :
    upper(replace(name, "-", "_")) => id
  }

  depends_on = [google_project_service.apis]
}
