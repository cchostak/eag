resource "google_secret_manager_secret" "config" {
  count     = var.existing_config_secret_id == "" ? 1 : 0
  secret_id = "eag-gateway-config${var.name_suffix}"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "config" {
  count       = var.existing_config_secret_id == "" ? 1 : 0
  secret      = google_secret_manager_secret.config[0].id
  secret_data = file(var.config_yaml_path)
}

resource "google_secret_manager_secret" "api_keys" {
  for_each = nonsensitive(var.api_keys)

  secret_id = "eag-${each.key}${var.name_suffix}"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "api_keys" {
  for_each = nonsensitive(var.api_keys)

  secret      = google_secret_manager_secret.api_keys[each.key].id
  secret_data = each.value
}
