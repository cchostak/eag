# Artifact Registry repo for mirroring gateway image

variable "project_id" { type = string }
variable "location" { type = string }
variable "repository_id" { type = string }
variable "name_suffix" {
  type    = string
  default = ""
}
variable "existing_repository_id" {
  type        = string
  default     = ""
  description = "If set, use this existing repo and skip creation"
}
variable "description" {
  type    = string
  default = "Gateway image mirror"
}

locals {
  repo_id           = var.repository_id != "" ? var.repository_id : "gateway"
  repo_id_effective = var.existing_repository_id != "" ? var.existing_repository_id : "${local.repo_id}${var.name_suffix}"
}

data "google_artifact_registry_repository" "existing" {
  count         = var.existing_repository_id != "" ? 1 : 0
  project       = var.project_id
  location      = var.location
  repository_id = var.existing_repository_id
}

resource "google_artifact_registry_repository" "gateway" {
  count         = var.existing_repository_id == "" ? 1 : 0
  project       = var.project_id
  location      = var.location
  repository_id = local.repo_id_effective
  description   = var.description
  format        = "DOCKER"
}

output "repository_url" {
  value = (
    var.existing_repository_id != ""
    ? "${var.location}-docker.pkg.dev/${var.project_id}/${data.google_artifact_registry_repository.existing[0].repository_id}"
    : "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.gateway[0].repository_id}"
  )
}
