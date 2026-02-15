# Artifact Registry repo for mirroring gateway image

variable "project_id" { type = string }
variable "location" { type = string }
variable "repository_id" { type = string }
variable "name_suffix" {
  type    = string
  default = ""
}
variable "description" {
  type    = string
  default = "Gateway image mirror"
}

locals {
  repo_id           = var.repository_id != "" ? var.repository_id : "gateway"
  repo_id_effective = "${local.repo_id}${var.name_suffix}"
}

resource "google_artifact_registry_repository" "gateway" {
  project       = var.project_id
  location      = var.location
  repository_id = local.repo_id_effective
  description   = var.description
  format        = "DOCKER"
}

output "repository_url" {
  value = "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.gateway.repository_id}"
}
