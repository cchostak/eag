variable "project_id" {
  type = string
}

variable "config_yaml_path" {
  type        = string
  description = "Path to the config.yaml to store in Secret Manager"
}

variable "api_keys" {
  type        = map(string)
  description = "Map of secret name => value for API keys"
  default     = {}
  sensitive   = true
}

variable "name_suffix" {
  type        = string
  default     = ""
  description = "Optional suffix appended to service account and secret IDs (include leading dash if desired)"
}

variable "existing_service_account_email" {
  type    = string
  default = ""
}

variable "existing_config_secret_id" {
  type    = string
  default = ""
}
