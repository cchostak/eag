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
