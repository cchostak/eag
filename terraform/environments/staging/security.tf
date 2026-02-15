module "security" {
  source = "../../modules/security"

  project_id       = var.project_id
  config_yaml_path = "${path.module}/../../../configs/staging/config.yaml"
  api_keys         = var.api_keys
  name_suffix      = var.name_suffix

  depends_on = [google_project_service.apis]
}
