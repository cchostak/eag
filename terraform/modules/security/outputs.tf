output "service_account_email" {
  value = google_service_account.eag.email
}

output "config_secret_id" {
  value = google_secret_manager_secret.config.secret_id
}

output "api_key_secret_ids" {
  value = {
    for name, secret in google_secret_manager_secret.api_keys :
    name => secret.secret_id
  }
}
