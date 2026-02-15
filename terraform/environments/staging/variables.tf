variable "project_id" {
  type = string
}

variable "primary_region" {
  type    = string
  default = "us-central1"
}

variable "regions" {
  type    = list(string)
  default = ["us-central1"]
}

variable "domain" {
  type = string
}

variable "tailscale_cidrs" {
  type = list(string)
}

variable "gateway_image" {
  type = string
  # Cloud Run accepts gcr.io, *.docker.pkg.dev, or docker.io images. Default to public Cloud Run hello image.
  default = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "source_gateway_image" {
  type        = string
  description = "Upstream image to mirror into Artifact Registry if use_artifact_registry_mirror is true"
  default     = "ghcr.io/agentgateway/agentgateway:0.12.0"
}

variable "use_artifact_registry_mirror" {
  type    = bool
  default = false
}

variable "artifact_registry_location" {
  type    = string
  default = "us"
}

variable "artifact_registry_repo" {
  type    = string
  default = "gateway"
}

variable "name_suffix" {
  type    = string
  default = "-stg2"
}

variable "enable_exports" {
  type    = bool
  default = false
}

variable "create_auth_metric" {
  type    = bool
  default = false
}

variable "create_auth_alert" {
  type    = bool
  default = false
}

variable "create_custom_service" {
  type    = bool
  default = false
}

variable "api_keys" {
  type      = map(string)
  default   = {}
  sensitive = true
}

variable "notification_email" {
  type        = string
  description = "Email to receive alert notifications"
  default     = ""
}

variable "log_retention_days" {
  type    = number
  default = 180
}

variable "log_archive_bucket" {
  type        = string
  description = "Override for the GCS bucket used to archive logs"
  default     = ""
}

variable "state_bucket_name" {
  type        = string
  description = "Override for the Terraform state bucket name"
  default     = ""
}
