module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id    = var.project_id
  location      = var.artifact_registry_location
  repository_id = var.artifact_registry_repo
}
