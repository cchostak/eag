variable "project_id" {
  type = string
}

variable "regions" {
  type        = list(string)
  description = "GCP regions to deploy to"
}

variable "image" {
  type        = string
  description = "Container image URI"
}

variable "config_secret_id" {
  type        = string
  description = "Secret Manager secret ID containing the gateway config"
}

variable "env_secrets" {
  type        = map(string)
  description = "Map of ENV_VAR_NAME => secret_id for runtime secrets"
  default     = {}
}

variable "service_account_email" {
  type = string
}

variable "min_instances" {
  type    = number
  default = 1
}

variable "max_instances" {
  type    = number
  default = 10
}

variable "cpu" {
  type    = string
  default = "2"
}

variable "memory" {
  type    = string
  default = "1Gi"
}
