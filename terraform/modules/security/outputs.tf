output "service_account_email" {
  value = var.existing_service_account_email != "" ? var.existing_service_account_email : google_service_account.eag[0].email
}

output "config_secret_id" {
  value = var.existing_config_secret_id != "" ? var.existing_config_secret_id : google_secret_manager_secret.config[0].secret_id
}

output "api_key_secret_ids" {
  value = {
    for name, secret in google_secret_manager_secret.api_keys :
    name => secret.secret_id
  }
}
