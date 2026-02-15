# Artifact Registry repo for mirroring gateway image

variable "project_id" { type = string }
variable "location" { type = string }
variable "repository_id" { type = string }
variable "description" {
  type    = string
  default = "Gateway image mirror"
}

resource "google_artifact_registry_repository" "gateway" {
  project       = var.project_id
  location      = var.location
  repository_id = var.repository_id
  description   = var.description
  format        = "DOCKER"
}

output "repository_url" {
  value = "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.gateway.repository_id}"
}
