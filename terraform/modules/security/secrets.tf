resource "google_secret_manager_secret" "config" {
  secret_id = "eag-gateway-config"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "config" {
  secret      = google_secret_manager_secret.config.id
  secret_data = file(var.config_yaml_path)
}

resource "google_secret_manager_secret" "api_keys" {
  for_each = nonsensitive(var.api_keys)

  secret_id = "eag-${each.key}"
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
