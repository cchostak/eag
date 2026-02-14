module "state_bucket" {
  source = "../../modules/state"

  project_id  = var.project_id
  bucket_name = var.state_bucket_name

  depends_on = [google_project_service.apis]
}
