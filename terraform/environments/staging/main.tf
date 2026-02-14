terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.primary_region
}

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
  type    = string
  default = "ghcr.io/agentgateway/agentgateway:0.12.0"
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

resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "compute.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudtrace.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "storage.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

module "state_bucket" {
  source = "../../modules/state"

  project_id  = var.project_id
  bucket_name = var.state_bucket_name

  depends_on = [google_project_service.apis]
}

module "security" {
  source = "../../modules/security"

  project_id       = var.project_id
  config_yaml_path = "${path.module}/../../../configs/staging/config.yaml"
  api_keys         = var.api_keys

  depends_on = [google_project_service.apis]
}

module "cloud_run" {
  source = "../../modules/cloud-run"

  project_id            = var.project_id
  regions               = var.regions
  image                 = var.gateway_image
  config_secret_id      = module.security.config_secret_id
  service_account_email = module.security.service_account_email
  min_instances         = 0
  max_instances         = 3

  env_secrets = {
    for name, id in module.security.api_key_secret_ids :
    upper(replace(name, "-", "_")) => id
  }

  depends_on = [google_project_service.apis]
}

module "networking" {
  source = "../../modules/networking"

  project_id      = var.project_id
  tailscale_cidrs = var.tailscale_cidrs
  cloud_run_negs  = module.cloud_run.neg_ids
  domain          = var.domain
}

module "logging" {
  source = "../../modules/logging"

  project_id          = var.project_id
  service_name        = "eag-gateway"
  retention_days      = var.log_retention_days
  archive_bucket_name = var.log_archive_bucket

  depends_on = [google_project_service.apis]
}

module "monitoring" {
  source = "../../modules/monitoring"

  project_id         = var.project_id
  notification_email = var.notification_email
  service_name       = "eag-gateway"

  depends_on = [google_project_service.apis]
}

output "project_id" {
  value = var.project_id
}

output "global_ip" {
  value = module.networking.global_ip
}

output "service_urls" {
  value = module.cloud_run.service_urls
}

output "state_bucket" {
  value       = module.state_bucket.bucket_name
  description = "GCS bucket for Terraform state (configure backend to use it)"
}
