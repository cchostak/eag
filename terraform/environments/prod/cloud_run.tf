module "cloud_run" {
  source = "../../modules/cloud-run"

  project_id            = var.project_id
  regions               = var.regions
  image                 = local.gateway_image_effective
  config_secret_id      = module.security.config_secret_id
  service_account_email = module.security.service_account_email
  min_instances         = var.min_instances
  max_instances         = var.max_instances
  service_name          = "eag-gateway"
  name_suffix           = var.name_suffix

  env_secrets = {
    for name, id in module.security.api_key_secret_ids :
    upper(replace(name, "-", "_")) => id
  }

  depends_on = [google_project_service.apis]
}
